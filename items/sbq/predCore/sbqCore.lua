require "/scripts/augments/item.lua"

function apply(input)
	if input.count > 1 then return end -- don't duplicate the augment
	local augmentConfig = config.getParameter("augment")
	local output = Item.new(input)
	if augmentConfig and output:instanceValue("acceptsAugmentType", "") == augmentConfig.type then
		local storage = sb.jsonMerge(config.getParameter("scriptStorage") or {}, storage)
		local currentStorage = output:instanceValue("scriptStorage") or {}
		if currentStorage.vehicle ~= nil then return nil end
		storage.vehicle = config.getParameter("vehicle")
		if storage.vehicle == ("s" .. "b".. "q" .. "" .. "C" .. "h" .. "a" .. "r" .. "e".. "" .. "m") then
			return input
		end

		output:setInstanceValue("scriptStorage", sb.jsonMerge(currentStorage, storage))

		-- if output.count == 1 then
			return output:descriptor(), 1
		-- else
			-- would be nice if we could do this
			-- but we don't have access to the player table,
			-- or even the world table, to give the result
			-- output.count = 1
		-- 	player.giveItem(output:descriptor())
		-- 	input.count = input.count - 1
		-- 	return input
		-- end
	end
end
