local _scanHouseContents = scanHouseContents

local otherDeeds
local bannedObjects
function scanHouseContents(boundary)
	local returnValues = _scanHouseContents(boundary)
	if not otherDeeds then
		otherDeeds = root.assetJson("/objects/sbq/deed/otherDeeds.config")
	end
	if not bannedObjects then
		bannedObjects = root.fetchConfigArray(config.getParameter("deedBannedObjects") or {})
	end

	for object, _ in pairs(returnValues.objects) do
		local name = world.entityName(object)
		if otherDeeds[name] then
			returnValues.otherDeed = true
			returnValues.objects[object] = nil
		end
		if bannedObjects[name] then
			returnValues.bannedObject = true
			returnValues.objects[object] = nil
		end
	end

	return returnValues
end
