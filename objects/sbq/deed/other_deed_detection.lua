local _scanHouseContents = scanHouseContents

local function fetchConfigArray(input, path)
	if (type(input) == "table") and input[1] then
		local out = input
		for _, v in ipairs(input) do
			out = fetchConfigArray(sb.jsonMerge(out, fetchConfigArray(v, path)), path)
		end
		return out
	elseif type(input) == "string" then
		return fetchConfigArray(root.assetJson(sbq.assetPath(input, path)), path)
	end
	return input
end

local otherDeeds
local bannedObjects
function scanHouseContents(boundary)
	local returnValues = _scanHouseContents(boundary)
	if not otherDeeds then
		otherDeeds = root.assetJson("/objects/sbq/deed/otherDeeds.config")
	end
	if not bannedObjects then
		bannedObjects = fetchConfigArray(config.getParameter("deedBannedObjects") or {})
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
