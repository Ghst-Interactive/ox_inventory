if not lib then return end

local shopTypes = {}
local shops = {}
local createBlip = require 'modules.utils.client'.CreateBlip

for shopType, shopData in pairs(lib.load('data.shops') or {} --[[@as table<string, OxShop>]]) do
	local shop = {
		name = shopData.name,
		groups = shopData.groups or shopData.jobs,
		blip = shopData.blip,
		label = shopData.label,
        icon = shopData.icon
	}

	--- A shop whose data carries `model`/`targets` uses `ghst_interact`, and only falls back to
	--- `locations`' plain markers when that is not running at all -- `ox_target` is off this
	--- server entirely as of 2026-09-05.
	if shared.interact then
		shop.model = shopData.model
		shop.targets = shopData.targets
	else
		shop.locations = shopData.locations
	end

	shopTypes[shopType] = shop
	local blip = shop.blip

	if blip then
		blip.name = ('ox_shop_%s'):format(shopType)
		AddTextEntry(blip.name, shop.name or shopType)
	end
end

--- The shop ped's id in `ghst_interact`, when that is the backend in use. Namespaced by the
--- entity handle rather than a counter: a handle is unique among currently-spawned peds, which is
--- exactly the lifetime one of these registrations has -- it is removed in `onExitShop`, below,
--- before the handle can be reused.
---@param entity number
---@return string
local function shopInteractId(entity)
	return ('ox_inventory:shop:%d'):format(entity)
end

---@param point CPoint
local function onEnterShop(point)
	if not point.entity then
		local model = lib.requestModel(point.ped)

		if not model then return end

		local entity = CreatePed(0, model, point.coords.x, point.coords.y, point.coords.z, point.heading, false, true)

		if point.scenario then TaskStartScenarioInPlace(entity, point.scenario, 0, true) end

		SetModelAsNoLongerNeeded(model)
		FreezeEntityPosition(entity, true)
		SetEntityInvincible(entity, true)
		SetBlockingOfNonTemporaryEvents(entity, true)

		--- A shop ped is an entity, `ghst_interact`'s prop/entity territory. Guarded rather than
		--- assumed from `shared.interact` alone -- the same `sync.ps1 -e` dev-restart case every
		--- other registration in this resource guards against.
		if shared.interact and GetResourceState('ghst_interact') == 'started' then
			pcall(function()
				exports.ghst_interact:create({
					id = shopInteractId(entity),
					entity = entity,
					--- Roughly the sternum: above the hands, below the face, which is where
					--- somebody's attention goes when they are being spoken to.
					---
					--- **The tree's ped offset, not a guess of this file's own.** The same number
					--- `ghst_appearance` puts on its shopkeepers and `ghst_launder` on its fronts,
					--- and for the reason both of them give: a ped is a rig and they all stand the
					--- same way up, so a second number here would be a third opinion about one
					--- skeleton. `/ibuild` settles it for all three at once if it is ever wrong.
					offset = vec3(0.0, 0.0, 0.95),
					options = {
						{
							icon = point.icon or 'fas fa-shopping-basket',
							label = point.label,
							groups = point.groups,
							onSelect = function()
								client.openInventory('shop', { id = point.invId, type = point.type })
							end,
							distance = point.shopDistance or 2.0,
						},
					},
				})
			end)
		end

		point.entity = entity
	end
end

local Utils = require 'modules.utils.client'

local function onExitShop(point)
	local entity = point.entity

	if not entity then return end

	if shared.interact and GetResourceState('ghst_interact') == 'started' then
		exports.ghst_interact:remove(shopInteractId(entity))
	end

	Utils.DeleteEntity(entity)

	point.entity = nil
end

local function hasShopAccess(shop)
	return not shop.groups or client.hasGroup(shop.groups)
end

local function wipeShops()
	for i = 1, #shops do
		local shop = shops[i]

		if shop.zoneId then
            Utils.RemoveBoxZone(shop.zoneId)
            shop.zoneId = nil
		end

		if shop.remove then
			if shop.entity then onExitShop(shop) end

			shop:remove()
		end

		if shop.blip then
			RemoveBlip(shop.blip)
		end
	end

	table.wipe(shops)
end

local function refreshShops()
	wipeShops()

	local id = 0

	for type, shop in pairs(shopTypes) do
		local blip = shop.blip
		local label = shop.label or locale('open_label', shop.name)

		if shared.interact then
			if shop.model then
				if not hasShopAccess(shop) then goto skipLoop end

				--- A model registration is exactly the `ghst_fuel`-shaped case `ghst_interact`
				--- exists for.
				if GetResourceState('ghst_interact') == 'started' then
					pcall(function()
						exports.ghst_interact:create({
							id = ('ox_inventory:shop:%s'):format(type),
							model = shop.model,
							--- A shop counter/rack is stood in front of, roughly chest height.
							--- **Unmeasured**, and shop models vary enough (racks, counters,
							--- machines) that this is a first guess rather than a claim -- `/ibuild`
							--- per shop model is how a bad one gets caught.
							offset = vec3(0.0, -0.4, 1.0),
							options = {
								{
									name = shop.name,
									icon = shop.icon or 'fas fa-shopping-basket',
									label = label,
									onSelect = function()
										client.openInventory('shop', { type = type })
									end,
									distance = 2,
								},
							},
						})
					end)
				end
			elseif shop.targets then
				for i = 1, #shop.targets do
					local target = shop.targets[i]
					local shopid = ('%s-%s'):format(type, i)

					if target.ped then
						id += 1

						shops[id] = lib.points.new({
							coords = target.loc,
							heading = target.heading,
							distance = 60,
							inv = 'shop',
							invId = i,
							type = type,
							blip = blip and hasShopAccess(shop) and createBlip(blip, target.loc),
							ped = target.ped,
							scenario = target.scenario,
							label = label,
							groups = shop.groups,
							icon = shop.icon or 'fas fa-shopping-basket',
							iconColor = target.iconColor,
							onEnter = onEnterShop,
							onExit = onExitShop,
							shopDistance = target.distance,
						})
					else
						if not hasShopAccess(shop) then goto nextShop end

						id += 1

						--- A box-shaped shop target is a rotated cuboid -- `ghst_interact`'s
						--- volume form, a `coords` place carrying `size`/`rotation`, since
						--- 2026-09-05. `Utils.CreateBoxZone` converts the legacy
						--- `loc`/`length`/`width`/`heading`/`minZ`/`maxZ` spelling this data still
						--- uses and states the anchor at the box's own centre.
						shops[id] = {
							zoneId = Utils.CreateBoxZone(('ox_inventory:shop:%s'):format(shopid), target, {
                                {
                                    name = shopid,
                                    icon = shop.icon or 'fas fa-shopping-basket',
                                    label = label,
                                    groups = shop.groups,
                                    onSelect = function()
                                        client.openInventory('shop', { id = i, type = type })
                                    end,
                                    iconColor = target.iconColor,
                                    distance = target.distance
                                }
                            }),
							blip = blip and createBlip(blip, target.coords or target.loc)
						}
					end

					::nextShop::
				end
			end
		elseif shop.locations then
			if not hasShopAccess(shop) then goto skipLoop end
            local shopPrompt = { icon = 'fas fa-shopping-basket' }

			for i = 1, #shop.locations do
				local coords = shop.locations[i]
				id += 1

				shops[id] = lib.points.new(coords, 16, {
					coords = coords,
					distance = 16,
					inv = 'shop',
					invId = i,
					type = type,
                    marker = client.shopmarker,
                    prompt = {
                        options = shop.icon and { icon = shop.icon } or shopPrompt,
                        message = ('**%s**  \n%s'):format(label, Utils.interactPrompt())
                    },
					nearby = Utils.nearbyMarker,
					blip = blip and createBlip(blip, coords)
				})
			end
		end

		::skipLoop::
	end
end

--- Registered again after `ghst_interact` restarts: model and ped registrations live in *its*
--- registry (`shopInteractId`s and `ox_inventory:shop:<type>`), and a restart empties it. Refresh
--- rather than re-add only the interact half, because `refreshShops` already wipes and rebuilds
--- everything idempotently -- a second, narrower path would be a second place to keep in sync.
AddEventHandler('onResourceStart', function(resource)
	if resource == 'ghst_interact' and shared.interact then refreshShops() end
end)

return {
	refreshShops = refreshShops,
	wipeShops = wipeShops,
}
