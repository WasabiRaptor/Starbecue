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

function sbq.tableMatches(a, b)
	local b = b or {}
    for k, v in pairs(a or {}) do
	  if type(v) == "table"
	  and type(b[k]) == "table"
	  and not sbq.tableMatches(v, b[k]) then
		return false
	  end
	  if v ~= b[k] then
		return false
	  end
	end
	return true
end

function sbq.metatableLayers(...)
    for _, table in ipairs({ ... }) do
		setmetatable(table, {__index = prevTable})
		prevTable = table
	end
end

function sbq.setupSettingMetatables(entityType)
    storage = storage or {}
    storage.sbqSettings = storage.sbqSettings or {}
    sbq.settings = sb.jsonMerge(sbq.settings or {}, sbq.voreConfig.overrideSettings or {})
	sbq.publicSettings = sbq.publicSettings or {}
    sbq.defaultSettings = sb.jsonMerge(
        sbq.config.defaultSettings,
        sbq.config.entityTypeDefaultSettings[entityType] or {},
        sbq.voreConfig.defaultSettings or {},
        storage.sbqSettings or {},
		sbq.settings or {}
    )
	-- using sb.jsonMerge to de-reference tables
	sbq.defaultSettings.locations = sb.jsonMerge(sbq.defaultSettings.locations or {}, {})
	storage.sbqSettings.locations = sb.jsonMerge(storage.sbqSettings.locations or {}, {})
	sbq.settings.locations = sb.jsonMerge(sbq.settings.locations or {}, {})
	sbq.publicSettings.locations = sb.jsonMerge(sbq.publicSettings.locations or {}, {})
	for name, location in pairs(sbq.voreConfig.locations or {}) do
		sbq.defaultSettings.locations[name] = sb.jsonMerge(sbq.defaultSettings.locations[name] or {}, {})
		storage.sbqSettings.locations[name] = sb.jsonMerge(storage.sbqSettings.locations[name] or {}, {})
		sbq.settings.locations[name] = sb.jsonMerge(sbq.settings.locations[name] or {}, {})
	end

	setmetatable(storage.sbqSettings, {__index = sbq.defaultSettings})
	setmetatable(sbq.settings, {__index= storage.sbqSettings})

    for name, location in pairs(sbq.voreConfig.locations or {}) do
		setmetatable(sbq.defaultSettings.locations[name], {__index = sbq.config.defaultLocationSettings})
		setmetatable(storage.sbqSettings.locations[name], {__index = sbq.defaultSettings.locations[name]})
		setmetatable(sbq.settings.locations[name], {__index= storage.sbqSettings.locations[name]})
    end
end

function sbq.replaceConfigTags(config, tags)
    local newConfig = {}
    for k, v in pairs(config) do
        local newKey = k
		if type(k) == "string" then
			newKey = sb.replaceTags(k, tags)
		end
		if type(v) == "table" then
            newConfig[newKey] = sbq.replaceConfigTags(v, tags)
		elseif type(v) == "string" then
			newConfig[newKey] = sb.replaceTags(v, tags)
        else
			newConfig[newKey] = v
		end
    end
	return newConfig
end

function sbq.distanceToLocal(pos, offset)
	return world.distance(pos, vec2.add(entity.position(), vec2.mul(offset or {0,0},{sbq.facingDirection, 1})))
end
