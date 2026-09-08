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
local Utils = require 'modules.utils.client'

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
--- **`offset` is `{ along, across, up }`, and `along` is not an axis.** It was: the three numbers
--- were x, y and z of the bounding box, with every point's x pinned at 0.5 and the barrel assumed
--- to run along the model's y. It does not -- on the Special Carbine MK2, measured in game on
--- 2026-09-08, the long axis is **x** -- so every point that fell back to an offset landed at the
--- same place along the gun and the four of them drew as one vertical stack of colliding labels
--- in the middle of the receiver.
---
--- Which axis it is need not be assumed at all: the longer of the model's x and y *is* the barrel,
--- and `frame` below resolves it per weapon, along with which end the muzzle is. 0 is the butt, 1
--- is the muzzle, 0.5 is the middle of the box, and the same seven rows now mean the same seven
--- places on a pistol as on a sniper.
--- **The bone lists are candidates and cost one hash lookup each**, so they are wide rather than
--- right. Two spellings are in circulation for most of these -- a second mount on a model that
--- takes two of something is `_2`, and the flashlight bone is the one usually written
--- `WAPFlshLasr` because the same mount carries the laser -- and there is no way to enumerate a
--- model's bone names from a script: `GetEntityBoneIndexByName` answers name-to-index and GTA V
--- has no index-to-name. So the list is tried in order and `report()` says which one won.
local POINTS = {
    { id = 'sight', bones = { 'WAPScop', 'WAPScop_2' }, offset = { 0.55, 0.5, 1.00 } },
    --- `gun_muzzle` FIRST, and `WAPSupp` behind it. Both resolve on a Carbine Rifle MK2 -- the
    --- report line on 2026-09-08 named `WAPSupp` because it was tried first -- and they are not
    --- the same place: `WAPSupp` is where a suppressor *mounts*, which on a shrouded barrel is
    --- somewhere back under the handguard, and `gun_muzzle` is the end of the barrel. The point is
    --- called muzzle and a player looks for it at the sharp end, so the tip wins and the mount is
    --- the fallback for a model that has no `gun_muzzle`.
    { id = 'muzzle', bones = { 'gun_muzzle', 'WAPSupp', 'WAPSupp_2' }, offset = { 1.00, 0.5, 0.55 } },
    { id = 'barrel', bones = {}, offset = { 0.78, 0.5, 0.55 } },
    { id = 'flashlight', bones = { 'WAPFlshLasr', 'WAPFlsh', 'WAPFlshLasr_2' }, offset = { 0.72, 0.5, 0.22 } },
    { id = 'grip', bones = { 'WAPGrip', 'WAPGrip_2' }, offset = { 0.62, 0.5, 0.05 } },
    { id = 'magazine', bones = { 'WAPClip', 'WAPClip_2', 'WAPClip_1' }, offset = { 0.42, 0.5, 0.00 } },
    { id = 'skin', bones = {}, offset = { 0.30, 0.5, 0.60 } },
}

--- The bones a weapon model puts at the sharp end, in the order they are worth trying. Used once
--- per weapon to decide which way round `along` runs -- see `frame`.
local NOSE = { 'gun_muzzle', 'WAPSupp', 'WAPFlsh' }

--- How far the model floats above the player while it is being looked at.
---
--- It has to be *somewhere*, and every candidate is a compromise: in front of the ped puts the
--- player in the background, and a fixed world position puts the weapon inside whatever is built
--- there. Straight up keeps the object with the player, so a session that ends badly leaves
--- nothing stranded across the map.
---
--- **Head height, not twelve metres.** It was twelve, on the reasoning that the backdrop would
--- then be sky rather than furniture -- and the shot that produced was a camera hanging over the
--- rooftops, which is what a player reported it as. Two things are wrong with the height. The
--- first is that it only reads as sky *outdoors*: inside an interior twelve metres up is inside
--- the ceiling slab, or above it and outside the interior's rooms entirely, where the game culls
--- what it draws. The second is that it is not what keeps the backdrop out of shot -- the framing
--- is. `place()` solves the camera distance from the stage rect, and on a full-screen stage that
--- distance is a couple of metres, so the model fills the frame and almost nothing else is in it.
---
--- Just clear of the ped is therefore enough, and it is the only value that behaves the same in a
--- garage as it does on a street.
local LIFT = 3.0

--- The field of view the shot is taken at. Fixed rather than a lens: nothing here is a photograph
--- and a second control on a screen whose point is the parts would be a control for its own sake.
local FOV = 40.0

--- How much of the stage rect's width the model spans. The wheel moves this; the distance falls
--- out of it, which is what keeps the model the same size when the rect changes.
local FILL_MIN, FILL_MAX = 0.25, 0.95

local object          --- @type number? the weapon object on the stage
local cam             --- @type number?
local hidden          --- @type number? the ped this screen made invisible, so it can be put back

--- Whether the SCREEN is up, which is not the same question as whether a model is on the stage.
---
--- Fitting a part rebuilds the model, and for the frame or two that takes `slot` and `object` are
--- both nil while the screen is very much still open. Anything asking "is the player looking at
--- attachments right now" has to read this rather than either of those, so it is written by the
--- page's own open and close and by nothing else in between.
local open = false
local slot            --- @type number? the player-inventory slot being looked at
local hash            --- @type number? the weapon's hash
local yaw = 35.0      --- degrees, clockwise from north, around the model
local pitch = 8.0     --- degrees above the horizon
local fill = 0.60
local rect = { x = 0.05, y = 0.15, w = 0.55, h = 0.7 }
local size = { x = 1.0, y = 0.4, z = 0.3 }  --- the model's own bounding box, metres
local centre = vec3(0.0, 0.0, 0.0)          --- the bbox centre in model space

--- Which of the model's own axes runs down the barrel, and which way. Solved per weapon in
--- `measure()`; `POINTS`' header says why it is solved rather than assumed.
local frame = { along = 'x', across = 'y', sign = 1.0 }

local MIN_PITCH, MAX_PITCH = -80.0, 80.0

--- Every point sent last frame, so an unchanged frame costs no NUI message.
---
--- The projection runs every frame because the camera and the model both move; *sending* it every
--- frame would be sixty messages a second for a screen that is usually still. The comparison is on
--- rounded screen fractions, which is the resolution the page can actually draw at anyway.
local sent = nil

--- The `POINTS` entries this weapon actually takes something for, in the order the page lists
--- them. Built by `catalogue()`; walked by `project()`.
---
--- The two used to disagree: the catalogue dropped a point the weapon takes nothing for -- see the
--- note below on why -- while the projection ran over all seven regardless. So a pistol drew a
--- `grip` dot that no row answered, and clicking it selected an id `stage.points` has never heard
--- of, which empties the whole right-hand column. One list, built once, read by both.
local active = nil

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

    local radians = math.rad(yaw)
    local tilt = math.rad(pitch)

    --- The model is turned by the orbit, so what it spans across the frame is somewhere between
    --- its length and its width. Using the length always is the safe end of that: a gun seen
    --- end-on is then smaller than asked for rather than hanging out of the hole.
    local reach = math.max(size.x, size.y)

    --- **How tall it is depends on the pitch, and pretending it is always as tall as it is long
    --- was what made the shot look like a distant camera.** The height term used to be
    --- `max(size.z, size.x)` -- the length, in the vertical -- which is only true looking straight
    --- down. At the resting pitch of eight degrees it asked for a rifle's *length* of headroom on
    --- a stage under a metre of it, so the height term won every time and stood the camera fifty
    --- per cent further back than the width needed: `fill` said 60% of the stage and the weapon
    --- drew at about 35%. It is the same fault `ghst_customs` avoids by solving distance from the
    --- free band's *width* alone -- this keeps a height term because the stage here can be short
    --- and wide, but the term is now what the model actually spans vertically at this angle.
    local lean = math.abs(tilt)
    local tall = size.z * math.cos(lean) + reach * math.sin(lean)

    local distance = math.max(reach / spanW, tall / spanH)

    local focus = GetOffsetFromEntityInWorldCoords(object, centre.x, centre.y, centre.z)

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
    ---
    --- **`right` is negative, and getting that wrong mirrored the shot.** The camera stands at
    --- heading `yaw` *from* the model, so it looks back along `(sin yaw, -cos yaw)` -- and the
    --- right hand of something facing that is `(-cos yaw, -sin yaw)`, not `(cos yaw, sin yaw)`.
    --- With the sign flipped the aim shifted the wrong way and the model landed reflected about
    --- the centre of the screen: a stage in the left two thirds of the page put the weapon in the
    --- right third, outside its own rect, with the dots drawn past 100% of an element they are
    --- positioned inside. What the player saw was an empty stage over a distant camera angle,
    --- which reads as the camera being in the wrong place rather than the aim.
    local right = vec3(-math.cos(radians), -math.sin(radians), 0.0)
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
---
--- **`pairs`, never `ipairs` or `#`.** `PlayerData.inventory` is keyed *by slot* and an empty slot
--- is a nil, not a placeholder -- `client.lua`'s `updateInventory` writes
--- `PlayerData.inventory[item.slot] = item.name and item or nil`. So the table is sparse, and
--- `#` on a sparse table is any border the implementation likes: with slot 4 empty it answers 3,
--- and a numeric loop stops there. Every part sitting past the player's first gap read
--- "Not in your bag" and `Fit` stayed disabled for it, on a bag that was holding one.
---@return table<string, number>
local function carried()
    local held = {}

    for slotId, item in pairs(PlayerData.inventory) do
        if item and item.name and not held[item.name] then held[item.name] = item.slot or slotId end
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
    local drawn = {}

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

            drawn[#drawn + 1] = point
        end
    end

    --- Replaced wholesale, and `sent` with it: the comparison in `project()` is index-by-index, so
    --- a list that has changed length or order has to start again rather than be diffed against
    --- the old one.
    active = drawn
    sent = nil

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

--- The world position of a named bone on the stage object, or nil.
---@param name string
---@return vector3?
local function boneAt(name)
    local bone = GetEntityBoneIndexByName(object, name)

    if not bone or bone == -1 then return end

    return GetWorldPositionOfEntityBone(object, bone)
end

--- The model's box, and which way round it is.
---
--- **The box is the base model's, not the assembled gun's.** `GetModelDimensions` answers for the
--- model hash; a fitted suppressor or scope is a separate drawable hung off a bone and is not in
--- it. So a heavily-kitted weapon sits a little forward of the centre of the frame -- the box is
--- honest about the receiver and short by the length of whatever is screwed to the end of it.
--- There is no native that answers the drawn extent, and the alternative -- unioning each fitted
--- component's own model box, placed at its mount bone -- is symmetric about a mount point rather
--- than about the part, so it would move the centre by roughly as much in the wrong direction.
---
--- **Which axis is the barrel is measured, not assumed.** The longer of x and y is it; the muzzle
--- end is found by asking a nose bone where it is in the model's own frame. Both are per weapon
--- and neither is a table anybody has to maintain. See `POINTS`.
local function measure()
    local minimum, maximum = GetModelDimensions(GetEntityModel(object))

    if not minimum or not maximum then return end

    size = {
        x = math.max(maximum.x - minimum.x, 0.05),
        y = math.max(maximum.y - minimum.y, 0.05),
        z = math.max(maximum.z - minimum.z, 0.05),
    }
    centre = (minimum + maximum) * 0.5

    frame = size.x >= size.y and { along = 'x', across = 'y', sign = 1.0 }
        or { along = 'y', across = 'x', sign = 1.0 }

    for i = 1, #NOSE do
        local at = boneAt(NOSE[i])

        if at then
            --- Back into the model's own frame, which is the frame `centre` and `POINTS` are in.
            local here = GetOffsetFromEntityGivenWorldCoords(object, at.x, at.y, at.z)
            local reading = frame.along == 'x' and here.x or here.y
            local middle = frame.along == 'x' and centre.x or centre.y

            --- A nose bone sitting *behind* the middle of the box means the model is built facing
            --- the other way, and every `along` reading has to be mirrored. A bone within a
            --- centimetre of the middle says nothing and is not trusted.
            if math.abs(reading - middle) > 0.01 then
                frame.sign = reading >= middle and 1.0 or -1.0
            end

            break
        end
    end
end

--- Where a point sits in the world this frame.
---
--- A bone where the model has one, and the box otherwise -- see `POINTS`. The fallback is read
--- through `frame`, so `offset[1]` means *along the barrel* whichever of the model's axes that
--- turns out to be and whichever end the muzzle is on.
---@param point table
---@return vector3
local function anchorOf(point)
    for i = 1, #point.bones do
        local at = boneAt(point.bones[i])

        if at then return at end
    end

    local offset = point.offset
    local along = (offset[1] - 0.5) * size[frame.along] * frame.sign
    local across = (offset[2] - 0.5) * size[frame.across]
    local x, y = along, across

    if frame.along == 'y' then x, y = across, along end

    return GetOffsetFromEntityInWorldCoords(
        object,
        centre.x + x,
        centre.y + y,
        centre.z + (offset[3] - 0.5) * size.z
    )
end

--- Weapons already reported on, so looking at the same gun twice costs one console line, not two.
local reported = {}

--- Say, once per weapon, where every dot on it is actually coming from.
---
--- **The one thing this file could never answer from the outside.** Its header has said since the
--- day it was written that which bones resolve on which models is unverifiable from here, and the
--- consequence was worse than not knowing: a dot in the wrong place looks exactly like a dot in
--- the right place until somebody who knows the weapon looks at it, and reading it back off a
--- screenshot is guesswork that has already been wrong once. A bone name that missed and a bone
--- name that hit are one line apart in the console and not distinguishable at all on the screen.
---
--- `lib.print.info` rather than a debug convar, because it fires once per weapon per session and
--- the two other `lib.print.info` calls in this resource are the same shape: something happened
--- that the next person debugging this would want to have been told.
local function report()
    if not hash or reported[hash] or not active then return end

    reported[hash] = true

    local bones, box = {}, {}

    for i = 1, #active do
        local point = active[i]
        local found

        for j = 1, #point.bones do
            if boneAt(point.bones[j]) then
                found = point.bones[j]
                break
            end
        end

        --- **Where it actually landed, as a fraction of the gun.** 0 is the butt and 1 is the
        --- muzzle end of the box, which is the same scale `POINTS` writes its fallbacks in -- so a
        --- dot in the wrong place stops being a thing to squint at in a screenshot and becomes a
        --- number to compare against the row above it. A bone is only ever a *guess* that a name
        --- means what it sounds like: `WAPSupp` is a suppressor mount, and whether that is at the
        --- end of the barrel or halfway back under a handguard is per model and unknowable here.
        local at = anchorOf(point)
        local here = GetOffsetFromEntityGivenWorldCoords(object, at.x, at.y, at.z)
        local reading = frame.along == 'x' and here.x or here.y
        local middle = frame.along == 'x' and centre.x or centre.y
        local along = 0.5 + frame.sign * (reading - middle) / size[frame.along]

        if found then
            bones[#bones + 1] = ('%s=%s@%.2f'):format(point.id, found, along)
        else
            box[#box + 1] = ('%s@%.2f'):format(point.id, along)
        end
    end

    --- The frame goes in the same line as the bones. It is the other half of where a dot lands --
    --- a box fallback is read along `frame.along` in the direction `frame.sign` says the muzzle
    --- is -- and a dot in the wrong place is one of the two, so printing one without the other
    --- means asking twice.
    lib.print.info(('weapon stage %s -- axis %s%s size %.2f/%.2f/%.2f -- bone: %s | box: %s'):format(
        PlayerData.inventory[slot] and PlayerData.inventory[slot].name or hash,
        frame.sign < 0 and '-' or '+', frame.along,
        size.x, size.y, size.z,
        #bones > 0 and table.concat(bones, ' ') or 'none',
        #box > 0 and table.concat(box, ' ') or 'none'
    ))
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
    if not object or not DoesEntityExist(object) or not active then return end

    local points = {}
    local changed = sent == nil or #sent ~= #active

    for i = 1, #active do
        local at = anchorOf(active[i])
        local ok, x, y = GetScreenCoordFromWorldCoord(at.x, at.y, at.z)

        --- Rounded to a thousandth of the stage, which is finer than a pixel on a 4K display and
        --- coarse enough that a still camera really does compare equal.
        local sx = ok and (x - rect.x) / rect.w or 0.0
        local sy = ok and (y - rect.y) / rect.h or 0.0

        local entry = {
            id = active[i].id,
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

--- Bumped by every `start`. The asset load in the middle of it yields, so a start that was
--- superseded while streaming -- the player picked a different weapon, or shut the screen -- has
--- to be able to tell that the world moved on and drop everything it was about to build.
local session = 0

--- The one hash this module has actually asked the streamer for, so that it releases only what it
--- took. A model that was already loaded when the screen opened -- the weapon in the player's
--- hands, or one another resource is holding -- was somebody else's request, and
--- `RemoveWeaponAsset` does not know whose it is giving back.
local streamed --- @type number?

--- Every component flag at once: flash, scope, suppressor, second clip, grip.
---
--- **`RequestWeaponAsset`'s last argument is not optional here, and leaving it at the default was
--- the whole of "the attachments only load after you have equipped the weapon once".** The
--- parameter is `ExtraWeaponComponentFlags`, `ox_lib` defaults it to `0` --
--- `WEAPON_COMPONENT_NONE` -- and the base weapon model streams without a single component model
--- behind it. `GiveWeaponComponentToWeaponObject` then succeeds and draws nothing: the gun stands
--- on the stage bare while the rail correctly lists a scope, a suppressor, a barrel, a flashlight,
--- a grip and an extended clip as fitted.
---
--- Equipping the weapon once is what used to fix it, and that is the tell. Putting the gun in the
--- ped's hands makes the game load the components it is wearing, and they are still resident when
--- the screen next opens -- so the bug looked like a caching problem and was a request that never
--- asked for them.
local COMPONENTS = 1 | 2 | 4 | 8 | 16

--- And every animation flag, which is `WRF_REQUEST_ALL_ANIMS` and what ox_lib defaults to.
local ANIMS = 31

--- Stream the weapon model and its component models in, and say whether they arrived.
---
--- **The asset is what was missing, and it is why the screen only ever worked for the gun in your
--- hands.** `CreateWeaponObject` answers 0 for a weapon whose asset is not loaded; the one in the
--- player's hands is loaded by definition, so that case worked and every weapon sitting in the bag
--- failed and fell through to the page's "cannot be shown here". Nothing logged, because a 0 from
--- that native is a return value rather than an error.
---
--- `lib.requestWeaponAsset` raises on timeout -- `lib.waitFor` does, and `streamingRequest` passes
--- the message straight through -- so it is caught here. A model that will not stream is a stage
--- that falls back to the rows, not a screen that throws.
---@param weapon number
---@return boolean
local function stream(weapon)
    streamed = weapon

    --- **Asked for unconditionally, ahead of the `HasWeaponAssetLoaded` short-circuit.** That
    --- native answers for the *weapon*, and a base model something else already loaded -- the ped
    --- equipping it, another resource giving it out -- answers true with no component models
    --- behind it. Re-requesting a resident asset is free; skipping the ask is a bare gun.
    RequestWeaponAsset(weapon, ANIMS, COMPONENTS)

    if HasWeaponAssetLoaded(weapon) then return true end

    --- Five seconds rather than the thirty ox_lib defaults to. This is in front of a player who is
    --- looking at a blank rectangle, and a weapon model that has not arrived in five is not going
    --- to be worth the next twenty-five.
    pcall(lib.requestWeaponAsset, weapon, 5000, ANIMS, COMPONENTS)

    return HasWeaponAssetLoaded(weapon) and true or false
end

--- Everything `stop` does except give the blur back.
---
--- Split out because `start` is also a stop: a fit rebuilds the model rather than patching it, and
--- a teardown that restored the blur would fade it in over the gun and back out again on every
--- part fitted. The blur belongs to the *screen being open*, not to the model being rebuilt.
---@param keep number? a weapon hash the caller is about to show, which must not be unloaded
local function teardown(keep)
    --- Anything still streaming for the old screen is now nobody's.
    session = session + 1

    --- **Given back only if this module took it, and only if nothing still wants it.**
    --- `RemoveWeaponAsset` withdraws a request without asking whose it was, so `streamed` is the
    --- record of having made one -- see above. The ped is the first thing that still wants the
    --- model, because the weapon in its hands is one the game is drawing; `keep` is the second, a
    --- rebuild of the same weapon, which would otherwise unload and re-stream once per part
    --- fitted.
    if streamed and streamed ~= keep and GetSelectedPedWeapon(cache.ped) ~= streamed then
        RemoveWeaponAsset(streamed)
        streamed = nil
    end

    slot = nil
    hash = nil
    sent = nil
    active = nil

    if object then
        if DoesEntityExist(object) then DeleteEntity(object) end

        object = nil
    end

    --- **The camera and the hidden ped belong to the SCREEN, not to the model.** `keep` means a
    --- model is about to be built in place of this one -- which is what fitting a part does, once
    --- per part -- and tearing the shot down for that put the player back in their own gameplay
    --- camera, in their own body, for the frame or two it took to rebuild. Every fit flashed.
    if keep then return end

    if cam then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(cam, true)
        cam = nil
    end

    if hidden then
        if DoesEntityExist(hidden) then SetEntityVisible(hidden, true, false) end

        hidden = nil
    end
end

--- Whether the attachments screen is on the player's screen right now.
---
--- Read by `client.lua`'s open-inventory watchdog, which is the only caller: fitting a part raises
--- `invBusy` for the length of the component's `usetime`, and the watchdog's rule is that a busy
--- player is not looking at an inventory. Here they are. See `canOpenInventory`.
---@return boolean
function Stage.isOpen()
    return open
end

--- @param closing boolean? true when the *inventory* is going away, not just this screen
function Stage.stop(closing)
    open = false

    teardown()

    --- **The blur is handed back unless the inventory is closing, in which case it is dropped.**
    ---
    --- `client.closeInventory` releases the resource's hold a line after it calls this, and the
    --- two fades cross if this one re-takes it first: a `TriggerScreenblurFadeIn(100)` and a
    --- `TriggerScreenblurFadeOut(250)` issued on the same frame leave the blur on the screen for
    --- the rest of the session. `Utils.blurOut` then sees the suspend still standing and returns
    --- without releasing anything, which is correct -- the hold was already given back when the
    --- screen took it, so the count is balanced and the blur is already off.
    if not closing then Utils.blurResume() end
end

--- **Yields.** The model has to stream in first, so every caller wraps this in a thread.
---@param target number the player-inventory slot holding the weapon
function Stage.start(target)
    local item = PlayerData.inventory[target]
    local data = item and item.name and Items[item.name]
    local weapon = data and data.weapon and (data.hash or joaat(item.name)) or nil

    --- Read before the teardown so it can be told what not to unload. A slot that is not a weapon
    --- still tears the old screen down -- the page has moved on either way.
    teardown(weapon)

    if not weapon then return Utils.blurResume() end

    local mine = session

    slot = target
    hash = weapon

    --- The rows first, and the model after. They are independent -- the catalogue is answered out
    --- of the item list and the player's bag, neither of which needs a model -- and the right-hand
    --- column is the half the player came here to use. Sending it before the wait means the screen
    --- is working while the gun is still arriving, rather than blank for both.
    catalogue()

    --- `live` is already false from the catalogue above, which is the fallback the page draws: no
    --- stage, but the rows still work. The request that did not arrive is still outstanding, and
    --- `teardown` is what withdraws it -- `stream` has already recorded it.
    if not stream(hash) then return end

    --- The player closed the screen, or opened a different weapon, while that streamed.
    if session ~= mine then return end

    local ped = cache.ped
    local at = GetEntityCoords(ped)

    --- **`true` for the default components, and it used to be `false`.**
    ---
    --- The reasoning for `false` was that the gun should wear exactly what the slot's metadata
    --- says it wears, and that a default clip GTA added on top would be drawing a magazine the
    --- player never fitted. That reads well and it is the wrong model of what a "component" is on
    --- an MK2 weapon: the **default barrel** is one. So is the default clip, and the default
    --- sight. They are not attachments the player chose -- they are the gun, and refusing them
    --- builds a rifle with no barrel on it.
    ---
    --- Which is exactly what showed: a Carbine Rifle MK2 with nothing in the `barrel` slot drew
    --- with the barrel missing, because `data/weapons.lua` has an item only for
    --- `COMPONENT_AT_*_BARREL_02` -- the heavy one -- and none at all for `_BARREL_01`. There is
    --- no metadata entry that could have put the standard barrel back, because there is no item
    --- for it to be.
    ---
    --- Fitted parts still win: GTA's component slots are mutually exclusive, so the extended clip
    --- given below replaces the default clip rather than sitting beside it. What `true` adds is
    --- the parts of the weapon that were never the player's to choose.
    object = CreateWeaponObject(hash, 0, at.x, at.y, at.z + LIFT, true, 1.0, 0)

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

    measure()

    --- Reused across a rebuild rather than recreated -- see `teardown`. `place()` below moves it
    --- to wherever this model wants it, so a weapon swap is a cut in the same shot.
    if not cam then
        cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, FOV, false, 0)

        SetCamActive(cam, true)
        RenderScriptCams(true, false, 0, true, true)
    end

    --- **The player is not in the shot.** The object has to exist somewhere in the world -- it is
    --- a real weapon object, not a picture -- and above the ped is the only place that is neither
    --- inside whatever is built there nor stranded across the map when a session ends badly. At
    --- the resting angles that puts the ped a few metres under the gun and out of frame, but the
    --- camera orbits and pitches, and a shot down onto the weapon is a shot of the player standing
    --- under it. Hidden locally, the same thing `ghst_customs` does to the driver it is sitting
    --- inside: it is a render flag on this client, the ped is still there and still animated.
    if not hidden then
        hidden = ped

        SetEntityVisible(ped, false, false)
    end

    --- **The blur comes off while the model is up.** `TriggerScreenblurFadeIn` is a full-screen
    --- post-process -- it is the only thing that can blur the game behind a translucent pane,
    --- because `backdrop-filter` never reaches the game frame -- and it blurs everything the frame
    --- contains, this weapon included. Every other surface in this resource *wants* that: the
    --- panes are read against the world and the world is not the content. Here it is, and a
    --- deliberately blurred subject is the one thing this screen cannot have.
    Utils.blurSuspend()

    place()
    catalogue()
    report()

    CreateThread(function()
        while session == mine and object and DoesEntityExist(object) do
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

--- `Stage.start` yields on the model, so both of its callers hand it a thread of its own rather
--- than yielding inside the NUI callback. The acknowledgement has already gone back by then; what
--- a yield here would actually hold up is the next message from the page, and the page sends one
--- per frame while a drag is in progress.
RegisterNUICallback('openWeaponStage', function(data, cb)
    cb(1)

    if type(data) ~= 'table' or type(data.slot) ~= 'number' then return end

    open = true

    if data.rect then setRect(data.rect) end

    CreateThread(function() Stage.start(data.slot) end)
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
    local target = slot

    CreateThread(function() Stage.start(target) end)
end)

--- A resource restart with the screen up leaves an object floating twelve metres above wherever
--- the player was standing, and a camera nobody owns.
AddEventHandler('onResourceStop', function(resource)
    if resource == shared.resource then Stage.stop() end
end)

--- **Closing the inventory closes the screen, and `client.closeInventory` says so directly.**
---
--- The page says so too -- the panel unmounts with the window and its teardown posts
--- `closeWeaponStage` -- and for a long time that was the only signal, on the reasoning that a
--- second answer to the same question is one answer too many. It is not a second answer: it is the
--- same one, arriving in a known order. A NUI message crosses a frame boundary, so the page's
--- version lands somewhere either side of the inventory's own blur release, and the two orderings
--- are not equivalent -- one of them crosses a fade in with a fade out and sticks the blur on. The
--- call from `closeInventory` runs first by construction and takes the ambiguity away; the page's
--- message still arrives and finds nothing left to stop.

return Stage
