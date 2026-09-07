if not lib then return end

local CraftingBenches = {}
local Items = require 'modules.items.client'
local createBlip = require 'modules.utils.client'.CreateBlip
local Utils = require 'modules.utils.client'
--- Built when the file loads, so the message resolves its key on demand rather than here -- see
--- the note on `textPrompts` in `modules/inventory/client.lua` for why that distinction matters.
local prompt = {
    options = { icon = 'fa-wrench' },
    message = function()
        return ('**%s**  \n%s'):format(locale('open_crafting_bench'), Utils.interactPrompt())
    end
}

--- Registers one bench's box zones with `ghst_interact`. Pulled out of `createCraftingBench` so
--- it can also run again on `onResourceStart`, below -- `sync.ps1 -e` restarts `ghst_interact` on
--- every save during dev, which empties its registry, and a bench that only ever registered at
--- file load would go dark on the next restart the way the reference file (`ghst_banking`'s
--- `atms.lua`) warns about.
---@param id number | string
---@param data table
local function registerCraftingZones(id, data)
	if not data.zones then return end

	for i = 1, #data.zones do
		local zone = data.zones[i]

		Utils.CreateBoxZone(('ox_inventory:crafting:%s:%s'):format(id, i), zone)
	end
end

---@param id number
---@param data table
local function createCraftingBench(id, data)
	CraftingBenches[id] = {}
	local recipes = data.items

	if recipes then
		data.slots = #recipes

		for i = 1, data.slots do
			local recipe = recipes[i]
			local item = Items[recipe.name]

			if item then
				recipe.weight = item.weight
				recipe.slot = i
			else
				warn(('failed to setup crafting recipe (bench: %s, slot: %s) - item "%s" does not exist'):format(id, i, recipe.name))
			end
		end

		local blip = data.blip

		if blip then
			blip.name = blip.name or ('ox_crafting_%s'):format(data.label and id or 0)
			AddTextEntry(blip.name, data.label or locale('crafting_bench'))
		end

		--- A crafting bench zone is a box (this data already carries the `coords`/`size`/
		--- `rotation` spelling `ghst_interact`'s volume form takes directly), registered through
		--- `Utils.CreateBoxZone` the same way `Inventory.Evidence`/`Inventory.Stashes` are.
		if shared.interact then
			data.points = nil
            if data.zones then
    			for i = 1, #data.zones do
    				local zone = data.zones[i]
    				zone.name = ('craftingbench_%s:%s'):format(id, i)
    				zone.id = id
    				zone.index = i
    				zone.options = {
						{
    						label = zone.label or locale('open_crafting_bench'),
    						canInteract = (zone.groups or data.groups) and function()
    							return client.hasGroup(zone.groups or data.groups)
    						end or nil,
    						onSelect = function()
    							client.openInventory('crafting', { id = id, index = i })
    						end,
    						distance = zone.distance or 2.0,
    						icon = zone.icon or 'fas fa-wrench',
    					}
    				}

    				if blip then
    					createBlip(blip, zone.coords)
    				end
    			end

				registerCraftingZones(id, data)
            end
		elseif data.points then
			data.zones = nil

			for i = 1, #data.points do
				local coords = data.points[i]

				lib.points.new({
					coords = coords,
					distance = 16,
					benchid = id,
					index = i,
					inv = 'crafting',
                    prompt = prompt,
                    marker = client.craftingmarker,
					nearby = Utils.nearbyMarker
				})

				if blip then
					createBlip(blip, coords)
				end
			end
		end

		CraftingBenches[id] = data
	end
end

for id, data in pairs(lib.load('data.crafting') or {}) do createCraftingBench(data.name or id, data) end

--- See the note on `registerCraftingZones` above: `CraftingBenches` already carries the built
--- `zones` tables (options, name, id, index all set), so a restart just re-submits them rather
--- than rebuilding from `data.crafting` a second time.
AddEventHandler('onResourceStart', function(resource)
	if resource ~= 'ghst_interact' then return end

	for id, data in pairs(CraftingBenches) do
		if shared.interact then registerCraftingZones(id, data) end
	end
end)

return CraftingBenches
