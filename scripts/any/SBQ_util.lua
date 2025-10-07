function sbq.fetchConfigArray(input, path)
	if (type(input) == "table") and input[1] then
		local out = input
		for _, v in ipairs(input) do
			out = sbq.fetchConfigArray(sb.jsonMerge(out, sbq.fetchConfigArray(v, path)), path)
		end
		return out
	elseif type(input) == "string" then
		return sbq.fetchConfigArray(root.assetJson(sbq.assetPath(input, path)), path)
	end
	return input
end

function sbq.query(input, query)
	if not input then return input end
	local out = input
	for _, v in ipairs(query) do
		out = out[v]
		if not out then return out end
	end
	return out
end

function sbq.splitKeys(path, pattern)
	local query = {}
	local path = path
	while path ~= "" do
		local found = path:find(pattern or "%.")
		if found then
			table.insert(query, path:sub(1, found - 1))
			path = path:sub(found + 1, -1)
		else
			table.insert(query, path:sub(1, -1))
			break
		end
	end
	return query
end

function sbq.queryPath(input, path)
	return sbq.query(input, sbq.splitKeys(path))
end

function sbq.setPath(input, path, value)
	local i = input
	for j, v in ipairs(path) do
		if j == #path then
			i[v] = value
			return true
		elseif type(i[v]) == "nil" then
			i[v] = {}
		elseif type(i[v]) ~= "table" then
			return false
		end
		i = i[v]
	end
end

function sbq.getClosestValue(x, list)
	local closest = list[1]
	local closestKey = 1
	local closestDiff = math.huge
	if not x then return closest, closestKey end
	for k, v in ipairs(list) do
		diff = math.abs(v - x)
		if diff <= closestDiff then
			closestDiff = diff
			closest = v
			closestKey = k
		end
	end
	return closest, closestKey
end

function sbq.tableMatches(a, b, maybeArrays)
	if not a then return true end
	local b = b or {}
	if maybeArrays and a[1] then
		for _, v in ipairs(a) do
			if sbq.tableMatches(v, b) then return true end
		end
		return false
	end
	for k, v in pairs(a or {}) do
		if type(v) == "table" and type(b[k]) == "table" then
			if not sbq.tableMatches(v, b[k]) then return false end
		elseif v ~= b[k] then
			return false
		end
	end
	return true
end

function sbq.metatableLayers(...)
	for _, table in ipairs({ ... }) do
		setmetatable(table, { __index = prevTable })
		prevTable = table
	end
end

function sbq.getEntitySize(entityId)
	if world.entityType(entityId) == "object" then
		return math.sqrt(#world.objectSpaces()) / sbq.config.sizeConstant
	end
	return math.sqrt(world.entity(entityId):collisionArea()) / sbq.config.sizeConstant
end

function sbq.getPublicProperty(entityId, property)
	if world.entityType(entityId) == "object" then
		return world.getObjectParameter(entityId, property)
	end
	return world.entity(entityId):statusProperty(property)
end

function sbq.getScriptParameter(entityId, property)
	local entityType = world.entityType(entityId)
	if entityType == "object" then
		return world.getObjectParameter(entityId, property)
	elseif entityType == "npc" then
		return world.getNpcScriptParameter(entityId, property)
	end
end

function sbq.entityName(entityId)
	if not entityId then return "nil" end
	if world.entityType(entityId) == "object" then
		return world.getObjectParameter(entityId, "entityName")
	end
	return world.entityName(entityId)
end

function sbq.entitySpecies(entityId)
	if world.entityType(entityId) == "object" then
		return world.getObjectParameter(entityId, "entitySpecies")
	end
	return world.entitySpecies(entityId)
end

function sbq.replaceConfigTags(config, tags)
	return sb.parseJson(sb.replaceTags(sb.printJson(config), tags))
end

function sbq.replace(from, to)
	if not to then return "" end
	local directive = "?replace;"
	for i, f in ipairs(from) do
		if to[i] then
			directive = directive .. f .. "=" .. to[i]:sub(1, 6) .. ";"
		end
	end
	return directive
end

function sbq.assetPath(path, directory)
	if string.sub(path, 1, 1) == "/" then
		return path
	else
		return (directory or "/") .. path
	end
end

function sbq.getActionIcon(action, preferDirectories, ignoreMissingIcon)
	for _, v in ipairs(preferDirectories) do
		local path = sbq.assetPath(action .. ".png", v)
		if v and root.assetOrigin(path) then
			return path
		end
	end
end

function sbq.globalToLocal(pos, offset)
	local facingDirection = sbq.facingDirection()
	local scale = sbq.getScale()
	pos = world.distance(pos, vec2.add(entity.position(), offset or { 0, 0 }))
	pos[1] = pos[1] * facingDirection / scale
	pos[2] = pos[2] / scale
	return pos
end

function sbq.localToGlobal(pos)
	local facingDirection = sbq.facingDirection()
	local scale = sbq.getScale()
	return { world.xwrap(pos[1] * facingDirection * scale), pos[2] * scale }
end

function sbq.getScaleLocal(pos)
	local facingDirection = sbq.facingDirection()
	local scale = sbq.getScale()
	return { pos[1] * facingDirection * scale, pos[2] * scale }
end

function sbq.globalPartPoint(part, property)
	return vec2.add(entity.position(), animator.partPoint(part, property))
end

function sbq.localPartPoint(part, property)
	return animator.transformPoint(animator.partProperty(part, property) or { 0, 0 }, part)
end

function sbq.localPartPoly(part, property)
	return animator.transformPoly(animator.partProperty(part, property) or { { 0.5, -0.5 }, { 0.5, 0.5 }, { -0.5, 0.5 },
		{ -0.5, -0.5 } }, part)
end

function sbq.logOutput(input, pretty)
	if pretty then
		input = sb.printJson(input, pretty, true)
	end
	return "[SBQ][%s:%s]%s", sbq.entityId(), (world.entityName(sbq.entityId()) or "-"), input
end

function sbq.logInfo(input, pretty)
	sb.logInfo(sbq.logOutput(input, pretty))
end

function sbq.logWarn(input, pretty)
	sb.logWarn(sbq.logOutput(input, pretty))
end

function sbq.logError(input, pretty)
	sb.logError(sbq.logOutput(input, pretty))
end

function sbq.debugLogInfo(input, pretty)
	if not (sbq.voreConfig or {}).debug or (sbq.config or {}).debug then return end
	sb.logInfo(sbq.logOutput(input, pretty))
end

function sbq.debugLogWarn(input, pretty)
	if not (sbq.voreConfig or {}).debug or (sbq.config or {}).debug then return end
	sb.logWarn(sbq.logOutput(input, pretty))
end

function sbq.debugLogError(input, pretty)
	if not (sbq.voreConfig or {}).debug or (sbq.config or {}).debug then return end
	sb.logError(sbq.logOutput(input, pretty))
end

function sbq.getString(str)
	if not str then return "" end
	if str:sub(1, 1) == ":" then
		if not sbq.strings then sbq.strings = root.assetJson("/sbqStrings.config") end
		str = sbq.strings[str:sub(2, -1)] or str
	end
	return str
end


function sbq.createdDateString(time)
	return os.date(sbq.getString(":createdOnDate"), time or os.time()) ..
		" v" .. root.assetSourceMetadata(root.assetOrigin("/sbq.config")).version
end

function sbq.createdDate(time) -- removes hour/min/sec for the sake of item stacking easier without using the collapse
	local table = os.date("*t", time or os.time())
	table.hour = 0
	table.min = 0
	table.sec = 0
	table.isdst = false
	return table
end

function sbq.isLoungeDismountable(eid)
	local loungeId, anchorIndex = world.entity(eid or entity.id()):anchorState()
	if loungeId then
		return (world.entity(loungeId):loungeAnchor(anchorIndex) or {dismountable = true}).dismountable
	else
		return true
	end
end
