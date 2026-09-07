if not lib then return end

local Utils = {}

function Utils.PlayAnim(wait, dict, name, blendIn, blendOut, duration, flag, rate, lockX, lockY, lockZ)
    lib.requestAnimDict(dict)
    TaskPlayAnim(cache.ped, dict, name, blendIn, blendOut, duration, flag, rate, lockX, lockY, lockZ)
    RemoveAnimDict(dict)

    if wait > 0 then Wait(wait) end
end

function Utils.PlayAnimAdvanced(wait, dict, name, posX, posY, posZ, rotX, rotY, rotZ, blendIn, blendOut, duration, flag,
                                time)
    lib.requestAnimDict(dict)
    TaskPlayAnimAdvanced(cache.ped, dict, name, posX, posY, posZ, rotX, rotY, rotZ, blendIn, blendOut, duration, flag,
        time, 0, 0)
    RemoveAnimDict(dict)

    if wait > 0 then Wait(wait) end
end

---@param flag number
---@param destination? vector3
---@param size? number
---@return number | false
---@return number?
function Utils.Raycast(flag, destination, size)
    local playerCoords = GetEntityCoords(cache.ped)
    destination = destination or GetOffsetFromEntityInWorldCoords(cache.ped, 0.0, 2.2, -0.25)
    local rayHandle = StartShapeTestCapsule(playerCoords.x, playerCoords.y, playerCoords.z + 0.5, destination.x,
        destination.y, destination.z, size or 2.2, flag or 30, cache.ped, 4)
    while true do
        Wait(0)
        local result, _, coords, _, entityHit = GetShapeTestResult(rayHandle)
        if result ~= 1 then
            -- DrawLine(playerCoords.x, playerCoords.y, playerCoords.z + 0.5, destination.x, destination.y, destination.z, 0, 0, 255, 255)
            -- DrawLine(playerCoords.x, playerCoords.y, playerCoords.z + 0.5, coords.x, coords.y, coords.z, 255, 0, 0, 255)
            local entityType
            if entityHit then entityType = GetEntityType(entityHit) end
            if entityHit and entityType ~= 0 then
                return entityHit, entityType
            end
            return false
        end
    end
end

function Utils.GetClosestPlayer()
    local players = GetActivePlayers()
    local playerCoords = GetEntityCoords(cache.ped)
    local targetDistance, targetId, targetPed

    for i = 1, #players do
        local player = players[i]

        if player ~= cache.playerId then
            local ped = GetPlayerPed(player)
            local distance = #(playerCoords - GetEntityCoords(ped))

            if distance < (targetDistance or 2) then
                targetDistance = distance
                targetId = player
                targetPed = ped
            end
        end
    end

    return targetId, targetPed
end

-- Replace ox_inventory notify with ox_lib (backwards compatibility)
function Utils.Notify(data)
    data.description = data.text
    data.text = nil
    lib.notify(data)
end

RegisterNetEvent('ox_inventory:notify', Utils.Notify)
exports('notify', Utils.Notify)

local notifySuppressed = false

---@param value boolean
local function setNotifySuppressed(value)
    notifySuppressed = value
end

RegisterNetEvent('ox_inventory:suppressItemNotifications', setNotifySuppressed)
exports('suppressItemNotifications', setNotifySuppressed)

function Utils.ItemNotify(data)
    if notifySuppressed or not client.itemnotify then
        return
    end

    SendNUIMessage({ action = 'itemNotify', data = data })
end

RegisterNetEvent('ox_inventory:itemNotify', Utils.ItemNotify)

---@deprecated
function Utils.DeleteObject(obj)
    SetEntityAsMissionEntity(obj, false, true)
    DeleteObject(obj)
end

function Utils.DeleteEntity(entity)
    if DoesEntityExist(entity) then
        SetEntityAsMissionEntity(entity, false, true)
        DeleteEntity(entity)
    end
end

local rewardTypes = 1 << 0 | 1 << 1 | 1 << 2 | 1 << 3 | 1 << 7 | 1 << 10

local weaponWheelOverride = false

---Enables the weapon wheel, but disables the use of inventory weapons.
---Mostly used for weaponised vehicles, though could be called for "minigames"
---@param state? boolean
---@param override? boolean
function Utils.WeaponWheel(state, override)
    if not override and weaponWheelOverride and state == false then
        return
    end
    if client.disableweapons then state = true end
    if state == nil then state = EnableWeaponWheel end

    if override then
        weaponWheelOverride = state or false
    end

    EnableWeaponWheel = state
    SetWeaponsNoAutoswap(not state)
    SetWeaponsNoAutoreload(not state)

    if client.suppresspickups then
        -- CLEAR_PICKUP_REWARD_TYPE_SUPPRESSION | SUPPRESS_PICKUP_REWARD_TYPE
        return state and N_0x762db2d380b48d04(rewardTypes) or N_0xf92099527db8e2a7(rewardTypes, true)
    end
end

exports('weaponWheel', function (state)
    Utils.WeaponWheel(state, true)
end)

function Utils.CreateBlip(settings, coords)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, settings.id)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, settings.scale)
    SetBlipColour(blip, settings.colour)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName(settings.name)
    EndTextCommandSetBlipName(blip)

    return blip
end

---Takes `ghst_interact`'s box-zone shape (`coords`/`size`/`rotation`) or the legacy
---`loc`/`length`/`width`/`heading`/`minZ`/`maxZ` spelling qtarget and `ox_target` both used, and
---registers it as a `place` with a volume.
---
---**The one funnel for every box zone in this resource** -- evidence, stashes and the box-shaped
---shop targets all call this rather than `exports.ghst_interact:create` directly, so the
---guard/pcall/re-register dance (`ghst_banking`'s `atms.lua` pattern) lives here once instead of
---three times over. The callers already rebuild themselves on a group change or on
---`ghst_interact` restarting -- `Inventory.Evidence()`/`Inventory.Stashes()` and
---`Shops.refreshShops()` -- so nothing here has to remember anything between calls.
---@param id string unique, namespaced by the caller
---@param data { coords: vector3, size: vector3, rotation: number? } | { length: number, minZ: number, maxZ: number, loc: vector3, heading: number, width: number, distance: number }
---@param options? OxTargetOption[]
---@return string id
function Utils.CreateBoxZone(id, data, options)
    if data.length then
        --- The legacy spelling never carried a point of its own, so the ANCHOR ghst_interact
        --- requires is the zone's own centre: x/y from `loc`, z at the midpoint of `minZ`/`maxZ`.
        --- That is not a guess -- it is the same point the box's own centre already was under
        --- `ox_target`, just stated rather than left for a zone object to compute.
        --- **`minZ` and `maxZ` are absolute world heights, not offsets from `loc`.** That is the
        --- PolyZone spelling every one of these tables was written in -- `data/evidence.lua`'s
        --- first locker is `loc.z` 30.69 between 29.49 and 32.09 -- so the centre is the midpoint
        --- of the pair and `loc.z` is not in it. Adding half the height to `loc.z` put this box a
        --- metre and a half up its own wall, where a player standing at the locker was outside it.
        local height = math.abs(data.maxZ - data.minZ)
        local z = (data.minZ + data.maxZ) / 2
        data.coords = vec3(data.loc.x, data.loc.y, z)
        data.size = vec3(data.width, data.length, height)
        data.rotation = data.heading
        data.loc = nil
        data.heading = nil
        data.length = nil
        data.width = nil
        data.maxZ = nil
        data.minZ = nil
    end

    if not data.options and options then
        local distance = data.distance or 2.0

        for k, v in pairs(options) do
            if not v.distance then
                v.distance = distance
            end
        end

        data.options = options
    end

    if GetResourceState('ghst_interact') == 'started' then
        pcall(function()
            exports.ghst_interact:create({
                id = id,
                coords = data.coords,
                size = data.size,
                rotation = data.rotation,
                options = data.options,
            })
        end)
    end

    return id
end

---Removes a box zone registered through `Utils.CreateBoxZone`. Guarded and `pcall`-wrapped for
---the same reason the create half is: a stash or shop can be re-scanned while `ghst_interact` is
---mid-restart, and a call into a stopped resource's export errors rather than no-oping.
---@param id string?
function Utils.RemoveBoxZone(id)
    if not id or GetResourceState('ghst_interact') ~= 'started' then return end

    pcall(function() exports.ghst_interact:remove(id) end)
end

local hasTextUi

--- `Interact with [E]`, except that the key is the player's rather than assumed.
---
--- **One function because there were five copies**, and every one of them was
--- `GetControlInstructionalButton(0, 38, true):sub(3)` -- which is right only while the token is
--- `t_` followed by a key name. On a pad control 38 answers `b_34`, and `:sub(3)` made that `34`:
--- the prompt read `Interact with [34]`. `ox_lib`'s `hints.lua` carries the measured alphabet and
--- `lib.keyLabel` is the one-key form of it.
---
--- The fallback is `E` because that is control 38's own default and there is nothing better to
--- say: a pad glyph is an icon, and no text stands in for it honestly. It is wrong for a pad
--- player who has never touched a keyboard, and it is still the better half of the trade -- a
--- key you can find is recoverable, and `34` is not.
---@return string
function Utils.interactPrompt()
    return locale('interact_prompt', lib.keyLabel({ control = 38 }, 'E'))
end

---@param point CPoint
function Utils.nearbyMarker(point)
    DrawMarker(point.marker.type, point.coords.x, point.coords.y, point.coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, point.marker.scale[1], point.marker.scale[2], point.marker.scale[3],
        ---@diagnostic disable-next-line: param-type-mismatch
        point.marker.colour[1], point.marker.colour[2], point.marker.colour[3], 222, false, false, 0, true, false, false, false)

    if point.isClosest and point.currentDistance < 1.2 then
        if not hasTextUi then
            hasTextUi = point
            --- A message may be a function, and the ones carrying a key are. Resolving a key
            --- into a string when the file loaded meant the prompt outlived the binding it was
            --- built from -- rebind the key, or pick up a pad, and it went on naming the old one
            --- until the resource restarted.
            local message = point.prompt.message

            lib.showTextUI(type(message) == 'function' and message() or message, point.prompt.options)
        end

        if IsControlJustReleased(0, 38) then
            CreateThread(function()
                if point.inv == 'policeevidence' then
                    client.openInventory('policeevidence')
                elseif point.inv == 'crafting' then
                    client.openInventory('crafting', { id = point.benchid, index = point.index })
                else
                    client.openInventory(point.inv or 'drop', { id = point.invId, type = point.type })
                end
            end)
        end
    elseif hasTextUi == point then
        hasTextUi = nil
        lib.hideTextUI()
    end
end

--[[
    THE SCREEN BLUR IS SHARED, AND THIS RESOURCE USED TO TREAT IT AS ITS OWN.

    `backdrop-filter` cannot reach the game frame -- NUI is composited over the rendered frame,
    not into it -- so the blur the inventory's translucent panes sit on has to be the game's own
    post-process. That part was always right here.

    What was wrong is that `TriggerScreenblurFadeOut` is ABSOLUTE. The old pair guarded with
    `IsScreenblurFadeRunning`, which answers whether a fade is currently in progress -- not
    whether anybody else still wants the blur. So closing the inventory over an open ox_lib
    dialog took the dialog's blur with it, and `DisableScreenblurFade` made it worse by cutting a
    running fade that belonged to someone else. `lib.screenBlur` counts holders; ten resources on
    this server blur, and before it existed any one of them could silently undo any other.

    HELD, not toggled. There are three open paths in `client.lua` and one close, so an
    uncounted-on-this-side call would climb the shared counter by two every session and never come
    back down. `blurred` is what makes this resource exactly one holder. It also makes `blurOut`
    safe to call unconditionally, which `client.lua` does -- the close path does not re-check
    `client.screenblur`, so a player with the setting off was already calling it.
]]
local blurred = false

function Utils.blurIn()
    if blurred then return end

    blurred = true
    lib.screenBlur(true, 100)
end

function Utils.blurOut()
    if not blurred then return end

    blurred = false
    lib.screenBlur(false, 250)
end

--[[
    A copy of the player, stood in front of the camera while the inventory is open.

    OFF BY DEFAULT, AND TUNABLE WITHOUT A REBUILD. `inventory:preview` switches it on;
    `inventory:previewoffset` is [distance, side, drop] in metres from the camera. Those
    three numbers decide the framing, and the right values depend on aspect ratio, FOV and
    how wide the two panes end up on a given screen — none of which can be guessed
    correctly from outside the game. Making them convars means nudging the ped into the
    margin is a server restart, not a UI rebuild. Negative `side` puts it to the left of
    the panes, which is where the empty screen is at 16:9.

    NOT A RENDER TARGET. This is a real ped standing in the world beside the camera, which
    is why it needs the light: it is lit by wherever the player actually is, so at night or
    indoors it would otherwise be a silhouette.
]]
local previewPed
local previewOffset = json.decode(GetConvar('inventory:previewoffset', '')) or { 2.2, -0.75, 0.7 }

---Forward and right vectors for the gameplay camera, both flattened enough to be useful.
---Right is deliberately level: sliding the ped sideways across the screen should not also
---slide it up or down when the player happens to be looking at the sky.
local function cameraBasis()
    local rot = GetGameplayCamRot(2)
    local z = math.rad(rot.z)
    local x = math.rad(rot.x)
    local cosX = math.abs(math.cos(x))

    return vec3(-math.sin(z) * cosX, math.cos(z) * cosX, math.sin(x)), vec3(math.cos(z), math.sin(z), 0.0), rot
end

function Utils.previewIn()
    -- Self-gating so the three places that open an inventory each call one unconditional
    -- line. A condition repeated at three call sites is a condition that gets it wrong at
    -- one of them.
    if not client.preview or previewPed then return end

    previewPed = ClonePed(cache.ped, false, false, true)

    if not previewPed or previewPed == 0 then
        previewPed = nil
        return
    end

    SetEntityInvincible(previewPed, true)
    SetEntityCanBeDamaged(previewPed, false)
    SetEntityCollision(previewPed, false, false)
    SetBlockingOfNonTemporaryEvents(previewPed, true)
    SetPedCanRagdoll(previewPed, false)
    -- Marked as a mission entity so DeleteEntity is guaranteed to take: an unmarked ped can
    -- be culled by the engine's own population manager, and then the delete does nothing
    -- and the handle is left dangling.
    SetEntityAsMissionEntity(previewPed, true, true)

    CreateThread(function()
        -- The camera does not turn while the inventory is open — SetNuiFocus captures the
        -- mouse — so this could in principle place the ped once. It runs every frame
        -- anyway, because DrawLightWithRange has to, and because a placement that survives
        -- the camera moving for any reason is one less thing that can look broken.
        while previewPed do
            local ped = previewPed
            local camera = GetGameplayCamCoord()
            local forward, right, rot = cameraBasis()

            local at = camera + forward * previewOffset[1] + right * previewOffset[2] -
                vec3(0.0, 0.0, previewOffset[3])

            SetEntityCoordsNoOffset(ped, at.x, at.y, at.z, false, false, false)
            -- Turned to face the camera rather than away from it, which is the whole point.
            SetEntityHeading(ped, rot.z + 180.0)
            DrawLightWithRange(at.x, at.y, at.z + 1.2, 255, 255, 255, 2.5, 6.0)

            Wait(0)
        end
    end)
end

function Utils.previewOut()
    if not previewPed then return end

    -- Cleared before the delete so the render thread above stops on its next tick rather
    -- than drawing against a handle that has just been freed.
    local ped = previewPed
    previewPed = nil

    Utils.DeleteEntity(ped)
end

-- A resource restart with the inventory open would otherwise leave the clone standing in
-- the world with nothing left to delete it.
AddEventHandler('onResourceStop', function(resource)
    if resource == shared.resource then Utils.previewOut() end
end)

---@param serverId number
---@return string
local function defaultGetPlayerName(serverId)
    local playerId = GetPlayerFromServerId(serverId)
    local playerName = GetPlayerName(playerId)
    return ('[%d] %s'):format(serverId, playerName)
end

local getPlayerName = defaultGetPlayerName

exports('setGetPlayerNameMethod', function (fn)
    if type(fn) == "function" then
        getPlayerName = fn
    else
        getPlayerName = defaultGetPlayerName
    end
end)

function Utils.getPlayerName(serverId)
    return getPlayerName(serverId)
end

return Utils
