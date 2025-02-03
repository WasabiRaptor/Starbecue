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

function sbq.tableMatches(a, b, maybeArrays)
	if not a then return true end
	local b = b or {}
	if maybeArrays and a[1] then
		for _, v in ipairs(a) do
			if sbq.tableMatches(v,b) then return true end
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
		setmetatable(table, {__index = prevTable})
		prevTable = table
	end
end

function sbq.refreshUpgrades(upgraded)
	storage.sbqSettings = storage.sbqSettings or {}
	storage.sbqUpgrades = storage.sbqUpgrades or {}
	sbq.upgradeScores = {}
	for k, v in pairs(storage.sbqUpgrades) do
		if type(v) == "table" then
			sbq.upgradeScores[k] = 0
			for _, value in pairs(v) do
				sbq.upgradeScores[k] = sbq.upgradeScores[k] + value
			end
		end
	end
	local oldMaxDigest = storage.sbqSettings.maxDigestPower
	local oldMaxScale = storage.sbqSettings.maxPossibleScale
	local candiesEaten = (sbq.upgradeScores.candiesEaten or 0)
	storage.sbqSettings.maxDigestPower = 1 + candiesEaten
	storage.sbqSettings.maxPossibleScale = math.min(2 + candiesEaten, sbq.config.scaleCap)
	if upgraded then
		for _, k in ipairs({"acidDigestPower", "cumDigestPower", "femcumDigestPower", "milkDigestPower"}) do
			if storage.sbqSettings[k] == oldMaxDigest then
				storage.sbqSettings[k] = storage.sbqSettings.maxDigestPower
			end
		end
		if storage.sbqSettings.maximumScale == oldMaxScale then
			storage.sbqSettings.maximumScale = storage.sbqSettings.maxPossibleScale
		end
	end
end

function sbq.validateExportSettings(settings)
	local validated = sb.jsonMerge(settings,{})
	validated.recentlyDigested = nil
	validated.infuseSlots = nil
	return sbq.removeEmptyTables(validated)
end
function sbq.removeEmptyTables(input)
	local empty = true
	for k, v in pairs(input) do
		if type(v) == "table" then
			input[k] = sbq.removeEmptyTables(v)
			if input[k] then
				empty = false
			end
		else
			empty = false
		end
	end
	if empty then return nil end
	return input
end

function sbq.checkInvalidSetting(value, setting, group, name)
	local value = tostring(value)
	local result = sbq.query(sbq.voreConfig.invalidSettings, {setting, value}) or ((group and name) and sbq.query(sbq.voreConfig.invalidSettings, {group, name, setting, value}))
	return sbq.query(sbq.worldInvalidSettings, {setting, result or value}) or ((group and name) and sbq.query(sbq.worldInvalidSettings, {group, name, setting, result or value})) or result
end
function sbq.checkLockedSetting(setting, group, name)
	return sbq.lockedSettings[setting] or ((group and name) and sbq.query(sbq.lockedSettings, {group, name, setting}))
end

function sbq.setupSettingMetatables(entityType)
	storage = storage or {}
	sbq.refreshUpgrades()
	sbq.voreConfig = sbq.voreConfig or {}
	sbq.worldInvalidSettings = sb.jsonMerge(world.getProperty("sbqInvalidSettings") or sbq.config.serverInvalidSettings or {}, world.getProperty("sbqInvalidSettings_"..entityType) or sbq.config.serverEntityTypeInvalidSettings[entityType] or {})
	storage.sbqSettings = storage.sbqSettings or {}

	-- sanity to remove potential data leak
	for k, v in ipairs(storage.sbqSettings.recentlyDigested or {}) do
		if sbq.query(v, {"parameters", "npcArgs", "npcParam", "scriptConfig", "sbqSettings", "recentlyDigested"}) then
			storage.sbqSettings.recentlyDigested[k].parameters.npcArgs.npcParam.scriptConfig.sbqSettings.recentlyDigested = nil
		end
		if sbq.query(v, {"parameters", "npcArgs", "npcParam", "scriptConfig", "sbqSettings", "infuseSlots"}) then
			storage.sbqSettings.recentlyDigested[k].parameters.npcArgs.npcParam.scriptConfig.sbqSettings.infuseSlots = nil
		end
		if sbq.query(v, {"parameters", "npcArgs", "npcParam", "scriptConfig", "initialStorage", "sbqSettings"}) then
			storage.sbqSettings.recentlyDigested[k].parameters.npcArgs.npcParam.scriptConfig.initialStorage.sbqSettings = nil
		end
	end
	for k, v in pairs(storage.sbqSettings.infuseSlots or {}) do
		if sbq.query(v, {"item", "parameters", "npcArgs", "npcParam", "scriptConfig", "sbqSettings", "recentlyDigested"}) then
			storage.sbqSettings.infuseSlots[k].item.parameters.npcArgs.npcParam.scriptConfig.sbqSettings.recentlyDigested = nil
		end
		if sbq.query(v, {"item", "parameters", "npcArgs", "npcParam", "scriptConfig", "sbqSettings", "infuseSlots"}) then
			storage.sbqSettings.infuseSlots[k].item.parameters.npcArgs.npcParam.scriptConfig.sbqSettings.infuseSlots = nil
		end
		if sbq.query(v, {"item", "parameters", "npcArgs", "npcParam", "scriptConfig", "initialStorage", "sbqSettings"}) then
			storage.sbqSettings.infuseSlots[k].item.parameters.npcArgs.npcParam.scriptConfig.initialStorage.sbqSettings = nil
		end

	end


	sbq.settings = sb.jsonMerge(
		sbq.config.entityTypeOverrideSettings[entityType] or {},
		sbq.voreConfig.overrideSettings or {}
	)
	for _, v in ipairs(sbq.config.infuseOverrideOrder or {}) do
		sbq.settings = sb.jsonMerge(sbq.settings, (sbq.infuseOverrideSettings or {})[v] or {})
	end
	sbq.settings = sb.jsonMerge(
		sbq.settings,
		world.getProperty("sbqOverrideSettings") or sbq.config.serverOverrideSettings or {},
		world.getProperty("sbqOverrideSettings_"..entityType) or sbq.config.serverEntityTypeOverrideSettings[entityType] or {}
	)
	if entityType == "player" then
		sbq.settings.speciesTF = nil
	end
	sbq.settings.recentlyDigested = nil

	sbq.lockedSettings = {}
	for setting, v in pairs(sbq.settings) do
		if not sbq.config.groupedSettings[setting] then
			sbq.lockedSettings[setting] = true
		end
	end
	for k, v in pairs(sbq.config.groupedSettings) do
		sbq.lockedSettings[k] = {}
		for name, settings in pairs(sbq.settings[k] or {}) do
			sbq.lockedSettings[k][name] = {}
			for setting, _ in pairs(settings or {}) do
				sbq.lockedSettings[k][name][setting] = true
			end
		end
	end

	sbq.publicSettings = sbq.publicSettings or {}
	sbq.defaultSettings = sb.jsonMerge(
		sbq.config.defaultSettings,
		sbq.config.entityTypeDefaultSettings[entityType] or {},
		sbq.voreConfig.defaultSettings or {}
	)
	for setting, v in pairs(storage.sbqSettings) do
		local defaultType = type(sbq.defaultSettings[setting])
		if (type(v) ~= defaultType) then
			storage.sbqSettings[setting] = nil
			if (sbq.defaultSettings[setting] == nil) then
				sbq.logWarn(string.format("Removed setting '%s' no defined default value.", setting))
			else
				sbq.logWarn(string.format("Defaulted setting '%s' value '%s'\nShould be type '%s'", setting, v, defaultType))
			end
		end
	end
	for setting, v in pairs(sbq.defaultSettings) do
		local override = sbq.settings[setting]
		local value = storage.sbqSettings[setting]
		if (type(v) == "table") and (storage.sbqSettings[setting] == nil) then
			storage.sbqSettings[setting] = {}
		end
		if not sbq.config.groupedSettings[setting] then
			local result = sbq.checkInvalidSetting(override or value or v, setting)
			if result ~= nil then
				sbq.settings[setting] = result
			end
		end
	end
	sbq.lists.locations = {}
	sbq.lists.voreTypes = {}
	sbq.lists.infuseTypes = {}
	sbq.lists.seekActions = {}
	for k, v in pairs(sbq.voreConfig.locations or {}) do
		table.insert(sbq.lists.locations,k)
	end
	for k, v in pairs(sbq.config.voreTypeData or {}) do
		table.insert(sbq.lists.voreTypes,k)
	end
	for k, v in pairs(sbq.config.infuseTypeData or {}) do
		table.insert(sbq.lists.infuseTypes,k)
	end
	for k, v in pairs(sbq.config.seekActionsSettings.dom) do
		table.insert(sbq.lists.seekActions, k)
	end
	for k, v in pairs(sbq.config.groupedSettings) do
		local list = {}
		if type(v.list) == "string" then
			list = sbq.lists[v.list] or {}
		elseif type(v.list) == "table" then
			list = v.list
		end
		sbq.defaultSettings[k] = sbq.defaultSettings[k] or {}
		sbq.publicSettings[k] = {}
		storage.sbqSettings[k] = storage.sbqSettings[k] or {}
		sbq.settings[k] = sbq.settings[k] or {}
		for _, name in ipairs(list) do
			sbq.defaultSettings[k][name] = sb.jsonMerge(
				v.defaultSettings or {},
				(sbq.voreConfig.groupedDefaultSettings or {})[k] or {},
				sbq.defaultSettings[k][name] or {}
			)
			sbq.publicSettings[k][name] = {}
			storage.sbqSettings[k][name] = storage.sbqSettings[k][name] or {}
			sbq.settings[k][name] = sbq.settings[k][name] or {}
			for setting, v in pairs(storage.sbqSettings[k][name]) do
				local defaultType = type(sbq.defaultSettings[k][name][setting])
				if (type(v) ~= defaultType) then
					storage.sbqSettings[k][name][setting] = nil
					if (sbq.defaultSettings[k][name][setting] == nil) then
						sbq.logWarn(string.format("Removed setting '%s.%s.%s'\nNo defined default value.", k, name, setting))
					else
						sbq.logWarn(string.format("Defaulted setting '%s.%s.%s' value '%s' to '%s'\nShould be type '%s'", k, name, setting, v, sbq.defaultSettings[setting], defaultType))
					end
				end
			end
			for setting, v in pairs(sbq.defaultSettings[k][name]) do
				sbq.settings[k][name][setting] = sbq.settings[k][name][setting] or sbq.settings[setting]
				local override = sbq.settings[k][name][setting]
				local value = storage.sbqSettings[k][name][setting]
				if (type(v) == "table") and (storage.sbqSettings[k][name][setting] == nil) then
					storage.sbqSettings[k][name][setting] = {}
				end
				local result = sbq.checkInvalidSetting(override or value or v, setting, k, name)
				if result ~= nil then
					sbq.settings[k][name][setting] = result
				end
			end

			setmetatable(storage.sbqSettings[k][name], {__index = sbq.defaultSettings[k][name]})
			setmetatable(sbq.settings[k][name], {__index= storage.sbqSettings[k][name]})
		end
	end

	for _, k in ipairs(sbq.lists.voreTypes) do
		if not (sbq.voreConfig.availableVoreTypes or {})[k] then
			sbq.settings.vorePrefs[k].pred = false
		end
	end
	for _, k in ipairs(sbq.lists.infuseTypes) do
		if not (sbq.voreConfig.availableInfuseTypes or {})[k] then
			sbq.settings.infusePrefs[k].pred = false
		end
	end

	setmetatable(storage.sbqSettings, {__index = sbq.defaultSettings})
	setmetatable(sbq.settings, {__index= storage.sbqSettings})
end


function sbq.getEntitySize(entityId)
	if world.entityType(entityId) == "object" then
		return math.sqrt(#world.objectSpaces()) / sbq.config.sizeConstant
	end
	return math.sqrt(world.entityArea(entityId)) / sbq.config.sizeConstant
end

function sbq.getPublicProperty(entityId, property)
	if world.entityType(entityId) == "object" then
		return world.getObjectParameter(entityId, property)
	end
	return world.entityStatusProperty(entityId, property)
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
			directive = directive .. f .. "=" .. to[i]:sub(1,6) .. ";"
		end
	end
	return directive
end

function sbq.getActionIcon(action, preferDirectories, ignoreMissingIcon)
	local directory = "/humanoid/any/sbqActionIcons/"
	if type(preferDirectories) ~= "table" then
		preferDirectories = {preferDirectories}
	end
	for _, v in ipairs(preferDirectories) do
		if v and root.assetExists(action..".png", v) then
			return v .. action .. ".png"
		end
	end
	if root.assetExists(action..".png", directory) then
		return directory .. action .. ".png"
	end
	if not ignoreMissingIcon then
		return directory .. "unassigned.png"
	end
end

function sbq.globalToLocal(pos, offset)
	local facingDirection = sbq.facingDirection()
	local scale = sbq.scale()
	pos = world.distance(pos, vec2.add(entity.position(), offset or {0,0}))
	pos[1] = pos[1] * facingDirection / scale
	pos[2] = pos[2] / scale
	return pos
end

function sbq.localToGlobal(pos)
	local facingDirection = sbq.facingDirection()
	local scale = sbq.scale()
	return {world.xwrap(pos[1] * facingDirection * scale), pos[2] * scale}
end

function sbq.scaleLocal(pos)
	local facingDirection = sbq.facingDirection()
	local scale = sbq.scale()
	return { pos[1] * facingDirection * scale, pos[2] * scale }
end

function sbq.globalPartPoint(part, property)
	return vec2.add(entity.position(), animator.partPoint(part, property))
end

function sbq.localPartPoint(part, property)
	return animator.transformPoint(animator.partProperty(part, property) or {0,0}, part)
end
function sbq.localPartPoly(part, property)
	return animator.transformPoly(animator.partProperty(part, property) or {{0.5,-0.5},{0.5,0.5},{-0.5,0.5},{-0.5,-0.5}}, part)
end

function sbq.logOutput(input, pretty)
	if pretty then
		input = sb.printJson(input, pretty, true)
	end
	return "[SBQ][%s:%s]%s", sbq.entityId(), (world.entityName(sbq.entityId()) or "-"), input
end
function sbq.logInfo(input, pretty)
	sb.logInfo(sbq.logOutput(input,pretty))
end
function sbq.logWarn(input, pretty)
	sb.logWarn(sbq.logOutput(input,pretty))
end
function sbq.logError(input, pretty)
	sb.logError(sbq.logOutput(input,pretty))
end
function sbq.debugLogInfo(input, pretty)
	if not sbq.voreConfig.debug then return end
	sb.logInfo(sbq.logOutput(input,pretty))
end
function sbq.debugLogWarn(input, pretty)
	if not sbq.voreConfig.debug then return end
	sb.logWarn(sbq.logOutput(input,pretty))
end
function sbq.debugLogError(input, pretty)
	if not sbq.voreConfig.debug then return end
	sb.logError(sbq.logOutput(input,pretty))
end

function sbq.getString(str)
	if not str then return "" end
	if str:sub(1, 1) == ":" then
		if not sbq.strings then sbq.strings = root.assetJson("/sbqStrings.config") end
		str = sbq.strings[str:sub(2, -1)] or str
	end
	return str
end

sbq.getSettingsOf = {}
function sbq.getSettingsOf.prefs()
	return sbq.validateExportSettings({
		vorePrefs = sbq.exportSettingGroup("vorePrefs"),
		infusePrefs = sbq.exportSettingGroup("infusePrefs"),
		domBehavior = sbq.exportSettingGroup("domBehavior"),
		subBehavior = sbq.exportSettingGroup("subBehavior")
	})
end
function sbq.getSettingsOf.locations()
	return sbq.validateExportSettings({
		locations = sbq.exportSettingGroup("locations"),
	})
end
function sbq.getSettingsOf.current()
	return sbq.validateExportSettings(sb.jsonMerge(storage.sbqSettings, {
		vorePrefs = sbq.exportSettingGroup("vorePrefs"),
		infusePrefs = sbq.exportSettingGroup("infusePrefs"),
		locations = sbq.exportSettingGroup("locations"),
		domBehavior = sbq.exportSettingGroup("domBehavior"),
		subBehavior = sbq.exportSettingGroup("subBehavior"),
	}))
end
function sbq.getSettingsOf.all()
	local output = sbq.exportBaseSettings()
	output.vorePrefs = sbq.exportSettingGroup("vorePrefs")
	output.infusePrefs = sbq.exportSettingGroup("infusePrefs")
	output.locations = sbq.exportSettingGroup("locations")
	output.domBehavior = sbq.exportSettingGroup("domBehavior")
	output.subBehavior = sbq.exportSettingGroup("subBehavior")
	return sbq.validateExportSettings(output)
end

function sbq.exportBaseSettings()
	local output = {}
	for k, _ in pairs(sbq.defaultSettings) do
		if not sbq.config.groupedSettings[k] then
			output[k] = sbq.settings[k]
		end
	end
	return output
end
function sbq.exportSettingGroup(group)
	local output = {}
	local list = {}
	local groupData = sbq.config.groupedSettings[group]
	if type(groupData.list) == "string" then
		list = sbq.lists[groupData.list] or {}
	elseif type(groupData.list) == "table" then
		list = groupData.list
	end
	for _, name in ipairs(list) do
		output[name] = {}
		for k, _ in pairs(groupData.defaultSettings) do
			output[name][k] = sbq.settings[group][name][k]
		end
	end
	return output
end

function sbq.createdDateString(time)
	return os.date(sbq.getString(":createdOnDate"), time or os.time()) .. " v" .. root.modMetadata("Starbecue").version
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
	local loungeAnchor = world.entityCurrentLounge(eid or entity.id())
	return (not loungeAnchor) or (loungeAnchor and loungeAnchor.dismountable)
end
