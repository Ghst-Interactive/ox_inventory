if not lib then return end

--- The weapon attachments screen's half of the work: the model, the camera, and the dots.
---
--- `docs/ui-tdu.md` §8's row for this resource ends with *"weapon attachments as a screen with the
--- LIVE weapon model orbited like the ped and its points projected on"*. The page cannot draw a
--- weapon -- CEF has no access to the renderer -- so the screen is a **hole**: the page leaves a
--- rectangle unpainted, tells this file where that rectangle is in viewport fractions, and this
--- file frames a weapon object into it with a scripted camera and draws nothing else. The dots are
--- the page's; all this side does is answer where each attachment point landed on screen.
---
--- **The object is not the ped's weapon.** The ped is behind the UI and its gun is in its hand at
--- whatever angle the animation left it; a camera orbiting that would orbit the player. So the
--- screen gets a `CreateWeaponObject` of its own, with the fitted components given to it, and it
--- is deleted on close. That is also what makes the screen work for a weapon in the bag rather
--- than in the hands -- fitting and removing still refuse in that case (see `inHand`), but looking
--- does not have to.
---
--- **`GetFinalRenderedCam*`, never `GetGameplayCam*`.** The gameplay camera answers where the ped
--- is standing the instant anything scripts a camera, which this file does.
--- `GetScreenCoordFromWorldCoord` projects from the rendered view itself, so the projection needs
--- no camera handle at all -- but the framing arithmetic below reads the rendered camera's own
--- vectors rather than the ones it just asked for, so a frame where the game has not applied the
--- move yet projects against the view the player is actually looking at.
---
--- The framing maths -- distance and the two shifts solved from a screen rect, a fill and a field
--- of view -- is `ghst_customs/client/camera.lua`'s, GPL to GPL; the orbit-and-zoom lifecycle is
--- `ghst_appearance/client/camera.lua`'s. What is new here is that the rect is *given* rather than
--- derived from a config: the page owns its own layout and is the only thing that knows where the
--- hole ended up.

local Items = require 'modules.items.client'

local Stage = {}

--- The attachment points, in the order the page lists them.
---
--- **A point is a component `type`**, which is the field `data/weapons.lua` already carries on
--- every entry in `Components` and the field the old panel used to caption a fitted part. There is
--- no second vocabulary: the seven ids here are exactly the seven distinct `type` values in that
--- file, so a component added later lands on a point that already exists.
---
--- `bones` are the weapon-model bone names GTA hangs each kind of part off. **They are candidates,
--- not a guarantee** -- a base model that takes a suppressor does not necessarily carry `WAPSupp`
--- until one is fitted -- so every point also has an `offset`, a position in the model's own
--- bounding box as fractions of it (x across, y along the barrel, z up). The offset is what a
--- point falls back to, and for `barrel` and `skin` it is all there is: neither names a bone in
--- any GTA weapon model, and a dot for the paint job has nowhere else to sit than the receiver.
---
--- **Unverified in game.** Which bones actually resolve on which models is the one thing this file
--- cannot check from here.
local POINTS = {
    { id = 'sight', bones = { 'WAPScop' }, offset = { 0.5, 0.50, 1.00 } },
    { id = 'muzzle', bones = { 'WAPSupp', 'gun_muzzle' }, offset = { 0.5, 1.00, 0.50 } },
    { id = 'barrel', bones = {}, offset = { 0.5, 0.78, 0.55 } },
    { id = 'flashlight', bones = { 'WAPFlsh' }, offset = { 0.5, 0.70, 0.30 } },
    { id = 'grip', bones = { 'WAPGrip' }, offset = { 0.5, 0.58, 0.00 } },
    { id = 'magazine', bones = { 'WAPClip', 'WAPClip_1' }, offset = { 0.5, 0.42, 0.00 } },
    { id = 'skin', bones = {}, offset = { 0.5, 0.26, 0.62 } },
}

--- How far the model floats above the player while it is being looked at.
---
--- It has to be *somewhere*, and every candidate is a compromise: in front of the ped puts the
--- player in the background, and a fixed world position puts the weapon inside whatever is built
--- there. Straight up keeps the backdrop to sky or ceiling and keeps the object with the player,
--- so a session that ends badly leaves nothing stranded across the map.
local LIFT = 12.0

--- The field of view the shot is taken at. Fixed rather than a lens: nothing here is a photograph
--- and a second control on a screen whose point is the parts would be a control for its own sake.
local FOV = 40.0

--- How much of the stage rect's width the model spans. The wheel moves this; the distance falls
--- out of it, which is what keeps the model the same size when the rect changes.
local FILL_MIN, FILL_MAX = 0.25, 0.95

local object          --- @type number? the weapon object on the stage
local cam             --- @type number?
local slot            --- @type number? the player-inventory slot being looked at
local hash            --- @type number? the weapon's hash
local yaw = 35.0      --- degrees, clockwise from north, around the model
local pitch = 8.0     --- degrees above the horizon
local fill = 0.60
local rect = { x = 0.05, y = 0.15, w = 0.55, h = 0.7 }
local size = { x = 0.4, y = 1.0, z = 0.3 }  --- the model's own bounding box, metres
local centre = vec3(0.0, 0.0, 0.0)          --- the bbox centre in model space

local MIN_PITCH, MAX_PITCH = -80.0, 80.0

--- Every point sent last frame, so an unchanged frame costs no NUI message.
---
--- The projection runs every frame because the camera and the model both move; *sending* it every
--- frame would be sixty messages a second for a screen that is usually still. The comparison is on
--- rounded screen fractions, which is the resolution the page can actually draw at anyway.
local sent = nil

--- --- Framing -----------------------------------------------------------------------------

--- Where the camera stands and what it aims at, so the model lands inside the page's hole.
---
--- The view is `2 * distance * tan(fov / 2) * aspect` wide at the model; the hole is `rect.w` of
--- that; the model is asked to span `fill` of the hole. Solving for distance is the first half.
--- Height is solved the same way and the larger of the two distances wins, because a rect that is
--- tall and narrow crops a pistol by its length and a short wide one crops a sniper by its scope.
---
--- The second half is the aim: the hole's centre is not the screen's, so the camera aims at a
--- point *offset* from the model by however far the two differ. Aiming at the model itself and
--- letting the page cover half of it is the version of this that looks like a bug in the page.
local function place()
    if not cam or not object or not DoesEntityExist(object) then return end

    local width, height = GetActiveScreenResolution()
    local aspect = (width and width > 0 and height and height > 0) and (width / height) or (16.0 / 9.0)

    local half = math.tan(math.rad(FOV) * 0.5)
    local spanW = 2.0 * fill * half * aspect * math.max(rect.w, 0.05)
    local spanH = 2.0 * fill * half * math.max(rect.h, 0.05)

    --- The model is turned by the orbit, so what it spans across the frame is somewhere between
    --- its length and its width. Using the length always is the safe end of that: a gun seen
    --- end-on is then smaller than asked for rather than hanging out of the hole.
    local reach = math.max(size.x, size.y)
    local distance = math.max(reach / spanW, math.max(size.z, size.x) / spanH)

    local focus = GetOffsetFromEntityInWorldCoords(object, centre.x, centre.y, centre.z)

    local radians = math.rad(yaw)
    local tilt = math.rad(pitch)
    local flat = distance * math.cos(tilt)

    --- A heading's forward vector in GTA's frame is `(-sin h, cos h)` -- clockwise from north,
    --- not the textbook anticlockwise from east.
    local eye = vec3(
        focus.x - math.sin(radians) * flat,
        focus.y + math.cos(radians) * flat,
        focus.z + distance * math.sin(tilt)
    )

    --- The camera's own right and up, from the same angles, so the shift below is in the frame
    --- the player is looking at rather than in the world's.
    local right = vec3(math.cos(radians), math.sin(radians), 0.0)
    local up = vec3(
        math.sin(radians) * math.sin(tilt),
        -math.cos(radians) * math.sin(tilt),
        math.cos(tilt)
    )

    local cx = rect.x + rect.w * 0.5
    local cy = rect.y + rect.h * 0.5
    local shiftRight = distance * half * aspect * (1.0 - 2.0 * cx)
    local shiftUp = distance * half * (2.0 * cy - 1.0)

    local aim = focus + right * shiftRight + up * shiftUp

    SetCamCoord(cam, eye.x, eye.y, eye.z)
    PointCamAtCoord(cam, aim.x, aim.y, aim.z)
    SetCamFov(cam, FOV)
end

--- --- The catalogue ------------------------------------------------------------------------

--- Whether the weapon takes any of a component item's hashes, and which one.
---
--- A component entry lists every GTA hash that means "this part", across every weapon that has a
--- version of it -- `at_suppressor_heavy` names four. `DoesWeaponTakeWeaponComponent` is the only
--- honest answer to whether *this* weapon is one of them, and it is client-side, which is why the
--- candidate list is built here rather than in the page.
---@param weapon number
---@param item table
---@return number? component
local function componentFor(weapon, item)
    local components = item.client and item.client.component

    if not components then return end

    for i = 1, #components do
        if DoesWeaponTakeWeaponComponent(weapon, components[i]) then return components[i] end
    end
end

--- What the player is carrying, by item name, with the slot it is in.
---
--- The slot is the payload: fitting a part is `useItem` on the slot holding it, which is the path
--- the resource already has (`client.lua`'s `useSlot`, the `data.component` branch). Nothing here
--- invents a second way to attach anything.
---@return table<string, number>
local function carried()
    local held = {}

    for i = 1, #PlayerData.inventory do
        local item = PlayerData.inventory[i]

        if item and item.name and not held[item.name] then held[item.name] = item.slot end
    end

    return held
end

--- The whole right-hand column, as one message.
---
--- Recomputed and re-sent rather than patched, because a fit or a removal changes three things at
--- once -- what is fitted, what is left in the bag, and which slot it is in -- and a page holding
--- two of the three would be right about the wrong one.
local function catalogue()
    if not slot or not hash then return end

    local item = PlayerData.inventory[slot]

    if not item then return end

    local fitted = item.metadata and item.metadata.components or {}
    local held = carried()
    local weapon = exports[shared.resource]:getCurrentWeapon()
    local inHand = weapon ~= nil and weapon.slot == slot

    local fittedByType = {}

    for i = 1, #fitted do
        local data = Items[fitted[i]]

        if data and data.type then fittedByType[data.type] = fitted[i] end
    end

    --- Every component this weapon takes, bucketed by point. Walking the whole item list once is
    --- cheaper than it looks -- it happens on open and on a change, not per frame -- and it is the
    --- only way to answer "what could go here" without a per-weapon table to maintain by hand.
    local options = {}

    for name, data in pairs(Items) do
        if data.type and componentFor(hash, data) then
            local bucket = options[data.type]

            if not bucket then
                bucket = {}
                options[data.type] = bucket
            end

            bucket[#bucket + 1] = {
                name = name,
                label = data.label or name,
                slot = held[name],
                fitted = fittedByType[data.type] == name,
            }
        end
    end

    local points = {}

    for i = 1, #POINTS do
        local point = POINTS[i]
        local bucket = options[point.id]

        --- A point the weapon takes nothing for is not a point on this weapon. Drawing all seven
        --- on a pistol would be five dots that answer "nothing fits here" -- which is not the same
        --- statement as "nothing is fitted here", and the row list has to be able to make the
        --- second one.
        if bucket then
            table.sort(bucket, function(a, b) return a.label < b.label end)

            points[#points + 1] = {
                id = point.id,
                fitted = fittedByType[point.id],
                options = bucket,
            }
        end
    end

    SendNUIMessage({
        action = 'weaponStage',
        data = {
            slot = slot,
            live = object ~= nil and DoesEntityExist(object),
            inHand = inHand,
            points = points,
        }
    })
end

--- --- The dots -----------------------------------------------------------------------------

--- Where a point sits in the world this frame.
---@param point table
---@return vector3
local function anchorOf(point)
    for i = 1, #point.bones do
        local bone = GetEntityBoneIndexByName(object, point.bones[i])

        if bone and bone ~= -1 then return GetWorldPositionOfEntityBone(object, bone) end
    end

    local offset = point.offset

    return GetOffsetFromEntityInWorldCoords(
        object,
        centre.x + (offset[1] - 0.5) * size.x,
        centre.y + (offset[2] - 0.5) * size.y,
        centre.z + (offset[3] - 0.5) * size.z
    )
end

--- Project every point and hand the page the fractions.
---
--- **Fractions of the stage, not of the screen.** This side already knows where the hole is -- it
--- had to, to frame the model into it -- so it does the division, and the page places a dot at
--- `left: x%` of its own element with no arithmetic and no second copy of the rect. It is also
--- what makes the harness possible: a fake point is a pair of numbers a human can read off the
--- mockup, rather than a viewport fraction that only means something at one window size.
---
--- `GetScreenCoordFromWorldCoord` answers `false` for a point behind the camera, which is a real
--- state on an orbited model -- the far side of the receiver goes behind the near side, not behind
--- the *camera*, but a muzzle can pass the near plane at full zoom. `visible` carries it rather
--- than the point being dropped, so the page keeps its dot in the list and simply stops drawing
--- it; a list that changes length is a list whose selection jumps.
local function project()
    if not object or not DoesEntityExist(object) then return end

    local points = {}
    local changed = sent == nil

    for i = 1, #POINTS do
        local at = anchorOf(POINTS[i])
        local ok, x, y = GetScreenCoordFromWorldCoord(at.x, at.y, at.z)

        --- Rounded to a thousandth of the stage, which is finer than a pixel on a 4K display and
        --- coarse enough that a still camera really does compare equal.
        local sx = ok and (x - rect.x) / rect.w or 0.0
        local sy = ok and (y - rect.y) / rect.h or 0.0

        local entry = {
            id = POINTS[i].id,
            x = math.floor(sx * 1000 + 0.5) / 1000,
            y = math.floor(sy * 1000 + 0.5) / 1000,
            visible = ok and true or false,
        }

        points[i] = entry

        if not changed then
            local was = sent[i]

            if not was or was.id ~= entry.id or was.x ~= entry.x or was.y ~= entry.y or was.visible ~= entry.visible then
                changed = true
            end
        end
    end

    if not changed then return end

    sent = points

    SendNUIMessage({ action = 'weaponPoints', data = { points = points } })
end

--- --- Lifecycle ----------------------------------------------------------------------------

function Stage.stop()
    slot = nil
    hash = nil
    sent = nil

    if cam then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(cam, true)
        cam = nil
    end

    if object then
        if DoesEntityExist(object) then DeleteEntity(object) end

        object = nil
    end
end

---@param target number the player-inventory slot holding the weapon
function Stage.start(target)
    Stage.stop()

    local item = PlayerData.inventory[target]

    if not item or not item.name then return end

    local data = Items[item.name]

    if not data or not data.weapon then return end

    slot = target
    hash = data.hash or joaat(item.name)

    local ped = cache.ped
    local at = GetEntityCoords(ped)

    --- `false` for the default components: the gun is shown wearing exactly what the slot's
    --- metadata says it wears, and letting GTA add a default clip on top would draw a magazine
    --- the player has not fitted.
    object = CreateWeaponObject(hash, 0, at.x, at.y, at.z + LIFT, false, 1.0, 0)

    if not object or object == 0 or not DoesEntityExist(object) then
        object = nil

        --- Still worth the catalogue: the right-hand column is the working half of the screen and
        --- it does not need a model. `live = false` is what tells the page to draw the rows
        --- without a stage, which is the fallback rather than a blank pane.
        catalogue()
        return
    end

    local fitted = item.metadata and item.metadata.components or {}

    for i = 1, #fitted do
        local component = Items[fitted[i]] and componentFor(hash, Items[fitted[i]])

        if component then GiveWeaponComponentToWeaponObject(object, component) end
    end

    if item.metadata and item.metadata.tint then
        SetWeaponObjectTintIndex(object, item.metadata.tint)
    end

    SetEntityCollision(object, false, false)
    FreezeEntityPosition(object, true)
    SetEntityInvincible(object, true)

    --- Level, and turned to nothing in particular: the orbit is the camera's, so the model holding
    --- still is what makes a drag read as walking round it rather than as spinning it.
    SetEntityRotation(object, 0.0, 0.0, 0.0, 2, true)

    local minimum, maximum = GetModelDimensions(GetEntityModel(object))

    if minimum and maximum then
        size = {
            x = math.max(maximum.x - minimum.x, 0.05),
            y = math.max(maximum.y - minimum.y, 0.05),
            z = math.max(maximum.z - minimum.z, 0.05),
        }
        centre = (minimum + maximum) * 0.5
    end

    cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, FOV, false, 0)

    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, true)

    place()
    catalogue()

    CreateThread(function()
        while object and DoesEntityExist(object) do
            place()
            project()
            Wait(0)
        end
    end)
end

--- --- The page's side ----------------------------------------------------------------------

---@param data { x: number, y: number, w: number, h: number }
local function setRect(data)
    if type(data) ~= 'table' then return end

    rect.x = tonumber(data.x) or rect.x
    rect.y = tonumber(data.y) or rect.y
    rect.w = math.max(tonumber(data.w) or rect.w, 0.05)
    rect.h = math.max(tonumber(data.h) or rect.h, 0.05)

    place()
end

RegisterNUICallback('openWeaponStage', function(data, cb)
    cb(1)

    if type(data) ~= 'table' or type(data.slot) ~= 'number' then return end

    if data.rect then setRect(data.rect) end

    Stage.start(data.slot)
end)

RegisterNUICallback('closeWeaponStage', function(_, cb)
    cb(1)
    Stage.stop()
end)

RegisterNUICallback('weaponStageRect', function(data, cb)
    cb(1)
    setRect(data)
end)

--- A drag, in degrees. The page reports the delta and this decides what a delta means, so the
--- clamp and the wrap live in one place rather than in both.
RegisterNUICallback('weaponStageOrbit', function(data, cb)
    cb(1)

    if type(data) ~= 'table' then return end

    yaw = (yaw + (tonumber(data.dx) or 0.0)) % 360.0
    pitch = math.min(MAX_PITCH, math.max(MIN_PITCH, pitch + (tonumber(data.dy) or 0.0)))

    place()
end)

--- The wheel, as a change in apparent size rather than in metres -- see `fill`.
RegisterNUICallback('weaponStageZoom', function(data, cb)
    cb(1)

    if type(data) ~= 'table' then return end

    fill = math.min(FILL_MAX, math.max(FILL_MIN, fill + (tonumber(data.delta) or 0.0)))

    place()
end)

--- The catalogue again, after a fit or a removal.
---
--- Asked for by the page rather than pushed on a timer, because the page is the only thing that
--- knows it has just sent a change and that the server's answer has landed as `refreshSlots`.
RegisterNUICallback('refreshWeaponStage', function(_, cb)
    cb(1)

    if not slot then return end

    --- The model has to be rebuilt, not patched: `RemoveWeaponComponentFromWeaponObject` exists,
    --- but the set of things to remove is the difference between two lists and rebuilding is the
    --- same work with no chance of the two drifting. The shot survives it -- `yaw`, `pitch` and
    --- `fill` are the session's, not the object's, so neither `stop` nor `start` touches them and
    --- a player who has turned the gun round is still looking at the same side of it.
    Stage.start(slot)
end)

--- A resource restart with the screen up leaves an object floating twelve metres above wherever
--- the player was standing, and a camera nobody owns.
AddEventHandler('onResourceStop', function(resource)
    if resource == shared.resource then Stage.stop() end
end)

--- Closing the inventory closes the screen with it, and the page is what says so: the panel
--- unmounts with the window, and its teardown posts `closeWeaponStage`. Watching `invOpen` here as
--- well would be a second answer to the same question, and the one that fires first would decide.

return Stage
