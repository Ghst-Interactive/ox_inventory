if not lib then return end

local Inventory = {}

Inventory.Dumpsters = lib.array:new(218085040, 666561306, -58485588, -206690185, 1511880420, 682791951)

if shared.networkdumpsters then
    -- Make sure dumpsters are frozen to ensure persistent position across clients
    SetInterval(function()
        local objects = GetGamePool('CObject')

        for i = 1, #objects do
            local object = objects[i]
            local state = Entity(object).state

            if state.isDumpster == nil then
                local model = GetEntityModel(object)
                local isDumpster = Inventory.Dumpsters:includes(model)

                state.isDumpster = isDumpster

                if isDumpster then
                    FreezeEntityPosition(object, true)
                end
            end
        end
    end, 3000)
end

function Inventory.OpenDumpster(entity)
    if shared.networkdumpsters then
        local coords = GetEntityCoords(entity)
        client.openInventory('dumpster', coords)
        return
    end

    local netId = NetworkGetEntityIsNetworked(entity) and NetworkGetNetworkIdFromEntity(entity)

    if not netId then
        local coords = GetEntityCoords(entity)
        entity = GetClosestObjectOfType(coords.x, coords.y, coords.z, 0.1, GetEntityModel(entity), true, true, true)
        netId = entity ~= 0 and NetworkGetNetworkIdFromEntity(entity)
    end

    if netId then
        client.openInventory('dumpster', 'dumpster' .. netId)
    end
end

local Utils = require 'modules.utils.client'
local Vehicles = lib.load('data.vehicles')
local backDoorIds = { 2, 3 }

function Inventory.CanAccessTrunk(entity)
    if cache.vehicle or not NetworkGetEntityIsNetworked(entity) then return end

    if IsEntityDead(entity) then return end

    --- A locked car has a locked boot. **Ghst-dev change**: upstream checks the class, the
    --- storage data, that the door exists and that you are within reach, and never asks whether
    --- the vehicle is locked -- so the prompt appeared on every car, including the ones
    --- `server.lua` was about to refuse. The glovebox needs no such line: reaching it means
    --- sitting in the driver's seat, which the lock already governs.
    ---
    --- THIS IS THE PROMPT, NOT THE GATE. `openInventory`'s trunk branch on the server has
    --- always tested `GetVehicleDoorLockStatus` and answered `vehicle_locked`, so a locked boot
    --- was never actually lootable. What this decides is whether the player is offered
    --- something that will work -- which is why it has to reach the *same* answer the server
    --- will, rather than a cheaper one.
    ---
    --- Read here rather than through `exports.ghst_vehiclekeys:IsAccessible`: `doorslockstate`
    --- is replicated to every client, so this costs no round trip and no export call, and no
    --- dependency on that resource being started.
    ---
    --- THE STATEBAG FIRST, THE NATIVE BEHIND IT. A world vehicle has no lock state until
    --- somebody tries a door, and testing the bag raw read every untouched car as unlocked --
    --- so the boot prompt appeared on cars the server then refused with `vehicle_locked`
    --- (server.lua's trunk branch has always checked the native). A prompt that lies is worse
    --- than no prompt. `ghst_vehiclekeys` documents this exact trap in `GhstKeys.lockState`,
    --- where reading "not 2" as unlocked made a lockpick report a car it had never rolled for.
    ---
    --- The rule is the server's, verbatim: 0 is no lock, 1 unlocked, 8 boot unlocked, and
    --- everything else -- 2, 3, 4, 7, 10 -- is locked. `== 2` alone missed five of them; that
    --- was safe only because ghst_vehiclekeys writes nothing but 1 and 2, which stops being
    --- true the moment the native answers instead.
    ---
    --- Keys are not consulted on purpose: the owner unlocks the car and then opens the boot,
    --- which is one press more and the same press a thief needs.
    local lockState = Entity(entity).state.doorslockstate or GetVehicleDoorLockStatus(entity)

    if lockState > 1 and lockState ~= 8 then return end

    local vehicleHash = GetEntityModel(entity)
    local vehicleClass = GetVehicleClass(entity)
    local checkVehicle = Vehicles.Storage[vehicleHash]

    if (checkVehicle == 0 or checkVehicle == 1) or (not Vehicles.trunk[vehicleClass] and not Vehicles.trunk.models[vehicleHash]) then return end

    ---@type number | number[]
    local doorId = checkVehicle and 4 or 5

    if not Vehicles.trunk.boneIndex?[vehicleHash] and not GetIsDoorValid(entity, doorId --[[@as number]]) then
        if vehicleClass ~= 11 and (doorId ~= 5 or GetEntityBoneIndexByName(entity, 'boot') ~= -1 or not GetIsDoorValid(entity, 2)) then
            return
        end

        if vehicleClass ~= 11 then
            doorId = backDoorIds
        end
    end

    local min, max = GetModelDimensions(vehicleHash)
    local offset = (max - min) * (not checkVehicle and vec3(0.5, 0, 0.5) or vec3(0.5, 1, 0.5)) + min
    offset = GetOffsetFromEntityInWorldCoords(entity, offset.x, offset.y, offset.z)

    if #(GetEntityCoords(cache.ped) - offset) < 1.5 then
        return doorId
    end
end

function Inventory.OpenTrunk(entity)
    ---@type number | number[] | nil
    local door = Inventory.CanAccessTrunk(entity)

    if not door then return end

    local coords = GetEntityCoords(entity)

    TaskTurnPedToFaceCoord(cache.ped, coords.x, coords.y, coords.z, 0)

    if not client.openInventory('trunk', { netid = NetworkGetNetworkIdFromEntity(entity), entityid = entity, door = door }) then return end

    if type(door) == 'table' then
        for i = 1, #door do
            SetVehicleDoorOpen(entity, door[i], false, false)
        end
    else
        SetVehicleDoorOpen(entity, door --[[@as number]], false, false)
    end
end

--- A dumpster and a vehicle boot are both props/entities, `ghst_interact`'s territory since
--- 2026-08-28. `ox_target` is off this server entirely as of 2026-09-05, so there is nothing left
--- to fall back to -- `shared.interact` being false just means neither is interactable, the same
--- guard the rest of this resource keeps.
if shared.interact then
    --- Guarded and re-registered the way `ghst_banking`'s `atms.lua` is: `sync.ps1 -e` restarts
    --- `ghst_interact` on every save during dev, which empties its registry, and a plain call at
    --- file-load time would only ever run once.
    local function addInteract()
        if GetResourceState('ghst_interact') ~= 'started' then return end

        pcall(function()
            exports.ghst_interact:create({
                id = 'ox_inventory:dumpster',
                model = Inventory.Dumpsters,
                --- A dumpster's model origin is the ground beneath it (the same failure
                --- `ghst_fuel`'s pumps had). Roughly lid height, and **unmeasured** -- `/ibuild`
                --- on one of `Inventory.Dumpsters` settles it.
                offset = vec3(0.0, 0.0, 0.9),
                options = {
                    {
                        icon = 'fas fa-dumpster',
                        label = locale('search_dumpster'),
                        distance = 2,
                        onSelect = function(data) return Inventory.OpenDumpster(data.entity) end,
                    },
                },
            })
        end)

        pcall(function()
            exports.ghst_interact:create({
                id = 'ox_inventory:trunk',
                --- `addGlobalVehicle` -> `class = 'vehicle'`, per the ladder table in
                --- `ghst_interact`'s README: a car is not a region you stand in or a fixed prop,
                --- it is a thing that moves and can be anywhere.
                class = 'vehicle',
                --- The boot lid bone, present on the overwhelming majority of the fleet.
                --- `CanAccessTrunk` below still does the real per-vehicle door/lock/class check --
                --- this only says where the prompt sits. **Unmeasured across the fleet as a
                --- whole** -- `/ibuild` catches a model where it lands wrong.
                bones = { 'boot', 'platelight' },
                options = {
                    {
                        icon = 'fas fa-truck-ramp-box',
                        label = locale('open_label', locale('storage')),
                        distance = 1.5,
                        canInteract = Inventory.CanAccessTrunk,
                        onSelect = function(data)
                            return Inventory.OpenTrunk(data.entity)
                        end,
                    },
                },
            })
        end)
    end

    addInteract()

    --- Evidence lockers and stashes are box zones registered through `Utils.CreateBoxZone`
    --- further down this file, and that registry is `ghst_interact`'s own -- a restart empties
    --- it the same way it empties the model/entity registrations above. Rebuilding through the
    --- module's own `__call` rather than a narrower re-add keeps one path idempotent instead of
    --- two things that can drift apart, the same argument `Shops.refreshShops` makes.
    AddEventHandler('onResourceStart', function(resource)
        if resource ~= 'ghst_interact' then return end

        addInteract()
        Inventory.Evidence()
        Inventory.Stashes()
    end)
end

---@param search 'slots' | 1 | 'count' | 2
---@param item table | string
---@param metadata? table | string
function Inventory.Search(search, item, metadata)
    if not PlayerData.loaded then
        if not coroutine.running() then
            error('player inventory has not yet loaded.')
        end

        repeat Wait(100) until PlayerData.loaded
    end

    if item then
        if search == 'slots' then search = 1 elseif search == 'count' then search = 2 end
        if type(item) == 'string' then item = { item } end
        if type(metadata) == 'string' then metadata = { type = metadata } end

        local items = #item
        local returnData = {}
        for i = 1, items do
            local item = string.lower(item[i])
            if item:sub(0, 7) == 'weapon_' then item = string.upper(item) end
            if search == 1 then
                returnData[item] = {}
            elseif search == 2 then
                returnData[item] = 0
            end
            for _, v in pairs(PlayerData.inventory) do
                if v.name == item then
                    if not v.metadata then v.metadata = {} end
                    if not metadata or table.contains(v.metadata, metadata) then
                        if search == 1 then
                            returnData[item][#returnData[item] + 1] = PlayerData.inventory[v.slot]
                        elseif search == 2 then
                            returnData[item] += v.count
                        end
                    end
                end
            end
        end
        if next(returnData) then return items == 1 and returnData[item[1]] or returnData end
    end
    return false
end

exports('Search', Inventory.Search)

exports('GetPlayerItems', function()
    return PlayerData.inventory
end)

exports('GetPlayerWeight', function()
    return PlayerData.weight
end)

exports('GetPlayerMaxWeight', function()
    return PlayerData.maxWeight
end)

local Items = require 'modules.items.client'

local function assertMetadata(metadata)
    if metadata and type(metadata) ~= 'table' then
        metadata = metadata and { type = metadata or nil }
    end

    return metadata
end

---@param itemName string
---@param metadata? any
---@param strict? boolean Strictly match metadata properties, otherwise use partial matching.
---@return SlotWithItem?
function Inventory.GetSlotWithItem(itemName, metadata, strict)
    local inventory = PlayerData.inventory
    local item = Items(itemName) --[[@as OxClientItem?]]

    if not inventory or not item then return end

    metadata = assertMetadata(metadata)
    local tablematch = strict and table.matches or table.contains

    for _, slotData in pairs(inventory) do
        if slotData and slotData.name == item.name and (not metadata or tablematch(slotData.metadata, metadata)) then
            return slotData
        end
    end
end

exports('GetSlotWithItem', Inventory.GetSlotWithItem)

---@param itemName string
---@param metadata? any
---@param strict? boolean Strictly match metadata properties, otherwise use partial matching.
---@return number?
function Inventory.GetSlotIdWithItem(itemName, metadata, strict)
    return Inventory.GetSlotWithItem(itemName, metadata, strict)?.slot
end

exports('GetSlotIdWithItem', Inventory.GetSlotIdWithItem)

---@param itemName string
---@param metadata? any
---@param strict? boolean Strictly match metadata properties, otherwise use partial matching.
---@return SlotWithItem[]?
function Inventory.GetSlotsWithItem(itemName, metadata, strict)
    local inventory = PlayerData.inventory
    local item = Items(itemName) --[[@as OxClientItem?]]

    if not inventory or not item then return end


    metadata = assertMetadata(metadata)
    local response = {}
    local n = 0
    local tablematch = strict and table.matches or table.contains

    for _, slotData in pairs(inventory) do
        if slotData and slotData.name == item.name and (not metadata or tablematch(slotData.metadata, metadata)) then
            n += 1
            response[n] = slotData
        end
    end

    return response
end

exports('GetSlotsWithItem', Inventory.GetSlotsWithItem)

---@param itemName string
---@param metadata? any
---@param strict? boolean Strictly match metadata properties, otherwise use partial matching.
---@return number[]?
function Inventory.GetSlotIdsWithItem(itemName, metadata, strict)
    local items = Inventory.GetSlotsWithItem(itemName, metadata, strict)

    if items then
        ---@cast items +number[]
        for i = 1, #items do
            items[i] = items[i].slot
        end

        return items
    end
end

---@param itemName string
---@param metadata? any
---@param strict? boolean Strictly match metadata properties, otherwise use partial matching.
---@return number
function Inventory.GetItemCount(itemName, metadata, strict)
    local inventory = PlayerData.inventory
    local item = Items(itemName) --[[@as OxClientItem?]]

    if not inventory or not item then return 0 end

    if not metadata then
        return item.count
    end


    metadata = assertMetadata(metadata)
    local count = 0
    local tablematch = strict and table.matches or table.contains

    for _, slotData in pairs(inventory) do
        if slotData and slotData.name == item.name and (not metadata or tablematch(slotData.metadata, metadata)) then
            count += slotData.count
        end
    end

    return count
end

exports('GetItemCount', Inventory.GetItemCount)


local function openEvidence()
    client.openInventory('policeevidence')
end

--- **The message is a function, and that is the point.** This table is built when the file loads,
--- so a key resolved here is the key as it was at resource start -- and it would then name that
--- key for the rest of the session, through any rebind and through the player picking up a pad.
--- `Utils.nearbyMarker` calls whatever it finds here, so the key is resolved at the moment the
--- prompt is drawn instead.
local textPrompts = {
    evidence = {
        options = { icon = 'fa-box-archive' },
        message = function()
            return ('**%s**  \n%s'):format(locale('open_police_evidence'), Utils.interactPrompt())
        end
    },
    stash = {
        options = { icon = 'fa-warehouse' },
        message = function()
            return ('**%s**  \n%s'):format(locale('open_stash'), Utils.interactPrompt())
        end
    }
}

--- **Both `Inventory.Evidence` and `Inventory.Stashes` below register through
--- `Utils.CreateBoxZone`.** Each is a box zone -- a rotated cuboid with width/length/height -- and
--- as of 2026-09-05 `ghst_interact` has a volume form for exactly that: a `coords` place carrying
--- `size`/`rotation`. The ANCHOR it draws the prompt at is the box's own centre, computed by
--- `Utils.CreateBoxZone` from the legacy `loc`/`minZ`/`maxZ` spelling this data still uses -- see
--- that function for why that point rather than a guess.
Inventory.Evidence = setmetatable(lib.load('data.evidence'), {
    __call = function(self)
        for index, evidence in pairs(self) do
            if evidence.point then
                evidence.point:remove()
            elseif evidence.zoneId then
                Utils.RemoveBoxZone(evidence.zoneId)
                evidence.zoneId = nil
            end

            if client.hasGroup(shared.police) then
                if shared.interact then
                    if evidence.target then
                        evidence.zoneId = Utils.CreateBoxZone(('ox_inventory:evidence:%s'):format(index), evidence.target, {
                            {
                                icon = evidence.target.icon or 'fas fa-warehouse',
                                label = locale('open_police_evidence'),
                                groups = shared.police,
                                onSelect = openEvidence,
                                iconColor = evidence.target.iconColor,
                            }
                        })
                    end
                else
                    evidence.target = nil
                    evidence.point = lib.points.new({
                        coords = evidence.coords,
                        distance = 16,
                        inv = 'policeevidence',
                        marker = client.evidencemarker,
                        prompt = textPrompts.evidence,
                        nearby = Utils.nearbyMarker
                    })
                end
            end
        end
    end
})

Inventory.Stashes = setmetatable(lib.load('data.stashes'), {
    __call = function(self)
        for id, stash in pairs(self) do
            if stash.jobs then stash.groups = stash.jobs end

            if stash.point then
                stash.point:remove()
            elseif stash.zoneId then
                Utils.RemoveBoxZone(stash.zoneId)
                stash.zoneId = nil
            end

            if not stash.groups or client.hasGroup(stash.groups) then
                if shared.interact then
                    if stash.target then
                        stash.zoneId = Utils.CreateBoxZone(('ox_inventory:stash:%s'):format(id), stash.target, {
                            {
                                icon = stash.target.icon or 'fas fa-warehouse',
                                label = stash.target.label or locale('open_stash'),
                                groups = stash.groups,
                                onSelect = function()
                                    exports.ox_inventory:openInventory('stash', stash.name)
                                end,
                                iconColor = stash.target.iconColor,
                            },
                        })
                    end
                else
                    stash.target = nil
                    stash.point = lib.points.new({
                        coords = stash.coords,
                        distance = 16,
                        inv = 'stash',
                        invId = stash.name,
                        marker = client.evidencemarker,
                        prompt = textPrompts.stash,
                        nearby = Utils.nearbyMarker
                    })
                end
            end
        end
    end
})

RegisterNetEvent('ox_inventory:refreshMaxWeight', function(data)
    if data.inventoryId == cache.serverId then
        PlayerData.maxWeight = data.maxWeight
    end

    SendNUIMessage({
        action = 'refreshSlots',
        data = {
            weightData = {
                inventoryId = data.inventoryId,
                maxWeight = data.maxWeight
            }
        }
    })
end)

RegisterNetEvent('ox_inventory:refreshSlotCount', function(data)
    SendNUIMessage({
        action = 'refreshSlots',
        data = {
            slotsData = {
                inventoryId = data.inventoryId,
                slots = data.slots
            }
        }
    })
end)

return Inventory
