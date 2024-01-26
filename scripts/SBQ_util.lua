function sbq.getClosestValue(x, list)
	local closest
	local closestKey
	local closestDiff = math.huge
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

function sbq.getConfigArray(config, path)
	if type(config) == "string" then return root.fetchJson(config, path or ("/humanoid/"..humanoid.species().."/")) end
	if not config[1] then return config end
	for i, merger in ipairs(config) do
		config[i] = sbq.getConfigArray(merger)
	end
	return config
end

function sbq.compareToLeftTable(a,b)
	for k, v in pairs(a) do
		if type(v) == "table" and not getmetatable(v) then
			setmetatable(v,{__eq = sbq.compareToLeftTable})
		end
		if type(b[k]) == "table" and not getmetatable(b[k]) then
			setmetatable(b[k],{__eq = sbq.compareToLeftTable})
		end
		sb.logInfo(k)
		if v ~= b[k] then return false end
	end
	return true
end
