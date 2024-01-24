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
	for _, merger in ipairs(config) do
		merger = sbq.getConfigArray(merger)
    end
	return config
end
