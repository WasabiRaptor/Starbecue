require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/rect.lua"
require "/scripts/poly.lua"
require "/scripts/interp.lua"
require "/scripts/any/SBQ_util.lua"
require "/scripts/any/SBQ_override_dummies.lua"

_Transformation = {}
_Transformation.__index = _Transformation

_State = {}
_State.__index = _State

_Action = {}
_Action.__index = _Action

_Location = {}
_Location.__index = _Location

_Occupant = {}
_Occupant.__index = _Occupant

Transformations = {}
Transformation = {
	locations = {},
	states = {}
}

Occupants = {
	list = {},
	seat = {},
	entityId = {},
	locations = {}
}

function controlPressed(seat, control, time)
	if Transformation.active and Occupants.seat[seat] then Occupants.seat[seat]:controlPressed(control, time) end
	-- sb.logInfo("Pressed:"..sb.printJson({seat,control,time}))
end
function controlReleased(seat, control, time)
	if Transformation.active and Occupants.seat[seat] then Occupants.seat[seat]:controlReleased(control, time) end
	-- sb.logInfo("Released:"..sb.printJson({seat,control,time}))
end

function sbq.init()
	sbq.lists = {}
	message.setHandler("sbqAddOccupant", function (_,_, ...)
		return Occupants.addOccupant(...)
	end)
	message.setHandler("sbqTryAction", function(_, _, ...)
		return sbq.tryAction(...)
	end)
	message.setHandler("sbqSettingsPageData", function ()
		return sbq.getSettingsPageData()
	end)
	message.setHandler("sbqSetGroupedSetting", function (_,_, ...)
		return sbq.setGroupedSetting(...)
    end)
	message.setHandler("sbqSetSetting", function (_,_, ...)
		return sbq.setSetting(...)
    end)
	message.setHandler("sbqSetUpgrade", function (_,_, ...)
		return sbq.getUpgrade(...)
    end)
	message.setHandler("sbqImportSettings", function (_,_, ...)
		return sbq.importSettings(...)
	end)
	message.setHandler("sbqActionList", function (_,_, ...)
		return sbq.actionList(...)
    end)
	message.setHandler("sbqRequestAction", function (_,_, ...)
		return sbq.requestAction(...)
    end)

	sbq.reloadVoreConfig(storage.lastVoreConfig)

	-- require "/scripts/misc/SBQ_convert_scripts.lua"
	-- sbq.createOccupantAnims()
end

function sbq.update(dt)
	sbq.facingRight = (sbq.facingDirection() == 1)
	if Transformation.active then
		Occupants.update(dt)
		Transformation:update(dt)
        Transformation.state:update(dt)
	end
	sbq.passiveStatChanges(dt)
end

function sbq.uninit()
	if Transformation.active then
		Transformation:uninit()
		Transformation.state:uninit()
		Transformation.active = false
	end
end

function sbq.passiveStatChanges(dt)
	if sbq.isResource("sbqLust") then
		local hornyPercent = sbq.resourcePercentage("sbqLust")
		if hornyPercent < sbq.stat("sbqLustScriptMax") then
			sbq.modifyResource("sbqLust", sbq.stat("sbqLustScriptDelta") * dt * sbq.resourcePercentage("food"))
		end
	end
	if sbq.isResource("sbqRest") then
		if sbq.isLounging() then
			sbq.modifyResource("sbqRest", sbq.stat("sbqRestScriptDelta") * dt * (sbq.resourcePercentage("health")))
		else
			sbq.modifyResource("sbqRest", sbq.stat("sbqRestScriptDelta") * dt * (1 - math.min(sbq.resourcePercentage("health"), 0.8)))
		end
	end
end

function sbq.size()
	return math.sqrt(sbq.area()) / sbq.config.sizeConstant
end

function sbq.reloadVoreConfig(config)
    sbq.clearStatModifiers("occupantModifiers")
	Occupants.refreshOccupantModifiers = true
	-- if reloading while another transformation is already active, uninitialize it first
	if Transformation.active then
		Transformation.state:uninit()
		Transformation:uninit()
		Transformation.active = false
	end
	-- store the last input so it's used again on the next initiaization
	storage.lastVoreConfig = config

	-- load config from species or config input, such as from a tech transformation
	sbq.voreConfig = root.fetchConfigArray(config or root.speciesConfig(humanoid.species()).voreConfig or "/humanoid/any/vore.config", sbq.directory())
	-- reset setting tables on reload
	sbq.setupSettingMetatables(entity.entityType())

	-- load scripts
	for _, script in ipairs(sbq.voreConfig.scripts or {}) do
		require(script)
	end
	Transformation = { locations = {}, states = {} }
	Transformation.transformation = Transformations[sbq.voreConfig.transformation or "default"]
	setmetatable(Transformation, {__index = Transformation.transformation})

	if sbq.voreConfig.pred.appendLists then
		for k, list in pairs(sbq.voreConfig.pred) do
			if type(list) == "table" and list[1] then
				util.appendLists(list, sbq.config.pred[k])
			end
		end
	end
	if sbq.voreConfig.prey.appendLists then
		for k, list in pairs(sbq.voreConfig.prey) do
			if type(list) == "table" and list[1] then
				util.appendLists(list, sbq.config.prey[k])
			end
		end
	end
	-- initial setup of location data based on species and infusion
	for location, locationData in pairs(sbq.voreConfig.locations) do
		Transformation:addLocation(location, locationData)
	end
	-- load states
	for name, stateConfig in pairs(sbq.voreConfig.states or {}) do
		Transformation:addState(name, stateConfig)
	end
	if not storage.lastState or (not (Transformation.states[storage.lastState])) then
		local defaultState = sbq.voreConfig.defaultState or "default"
		Transformation.state = Transformation.states[defaultState]
		Transformation.stateName = defaultState
	else
		Transformation.state = Transformation.states[storage.lastState]
		Transformation.stateName = storage.lastState
	end
	-- put settings meant to be public and accessible by other entities in a status property
    sbq.refreshPublicSettings()
	sbq.refreshSettings()
	Transformation:init()
	Transformation.state:init()
    Transformation.active = true
end

function sbq.actionList(type, target)
    local list = {}
    local actions = sb.jsonMerge({}, sbq.voreConfig.actionList)
	if target then
        local occupant = Occupants.entityId[tostring(target)]
        if occupant then
            actions = sb.jsonMerge({}, occupant:getLocation().locationActions)
            table.insert(actions, 1, { action = "letout", noDisplay = { predRadialMenuSelect = true } })
		end
	end
	for _, action in ipairs(actions or {}) do
        local available, reason = Transformation:actionAvailable(action.action, target, table.unpack(action.args or {}))
		if (not sbq.config.dontDisplayAction[tostring(reason)]) and not (action.noDisplay or {})[type] then
			table.insert(list, sb.jsonMerge(action, {available = available}))
		end
    end
	sbq.logInfo(list, 2)
	return list
end

function sbq.tryAction(action, target, ...)
	if not Transformation.active then return {false, "inactive"} end
	return {Transformation:tryAction(action, target, ...)}
end

function sbq.actionAvailable(action, target, ...)
	if not Transformation.active then return {false, "inactive"} end
	return {Transformation:actionAvailable(action, target, ...)}
end

function sbq.requestAction(action, target, consent, ...)
	if not Transformation.active then return {false, "inactive"} end
	return {Transformation:requestAction(action, target, consent, ...)}
end

function sbq.getOccupantData(entityId)
    local occupant = Occupants.entityId[tostring(entityId)]
    if not occupant then return false end
	location = occupant:getLocation()
    return {
        occupant,
		location:outputData(entityId)
	}
end

function sbq.getSettingsPageData()
	local settingsPageData = {
        storageSettings = storage.sbqSettings or {},
		storageUpgrades = storage.sbqUpgrades or {},
		settings = sbq.settings or {},
		voreConfig = sbq.voreConfig or {},
        locations = Transformation.locations or {},
		currentScale = sbq.scale()
	}
	return settingsPageData
end

function sbq.setSetting(k, v)
	local old = sbq.settings[k]
	storage.sbqSettings[k] = v
	if old == sbq.settings[k] then return end
	sbq.refreshSettings()
	if sbq.config.publicSettings[k] then
		sbq.publicSettings[k] = sbq.settings[k]
		sbq.setProperty("sbqPublicSettings", sbq.publicSettings)
    end
	if (sbq.voreConfig.settingUpdateScripts or {})[k] then
		for _, script in ipairs(sbq.voreConfig.settingUpdateScripts[k]) do
			sbq[script](k,v)
		end
	end
end

function sbq.getUpgrade(upgradeName, tier, bonus)
    storage.sbqUpgrades[upgradeName] = storage.sbqUpgrades[upgradeName] or {}
    storage.sbqUpgrades[upgradeName][tier] = math.max(storage.sbqUpgrades[upgradeName][tier] or 0, bonus)
	sbq.refreshUpgrades(true)
end

function sbq.setGroupedSetting(group, name, k, v)
	local old = sbq.settings[group][name][k]
	storage.sbqSettings[group][name][k] = v
    if old == sbq.settings[group][name][k] then return end
    if sbq.groupedSettingChanged[group] then sbq.groupedSettingChanged[group](name, k, v) end
	if (sbq.voreConfig.settingUpdateScripts or {})[k] then
		for _, script in ipairs(sbq.voreConfig.settingUpdateScripts[k]) do
			sbq[script](k,v, group, name)
		end
	end
	sbq.refreshSettings()
	if sbq.config.publicSettings[k] then
		sbq.publicSettings[group][name][k] = sbq.settings[group][name][k]
		sbq.setProperty("sbqPublicSettings", sbq.publicSettings)
	end
end

function sbq.importSettings(newSettings)
    storage.sbqSettings = sb.jsonMerge(storage.sbqSettings, newSettings)
    sbq.setupSettingMetatables(entity.entityType())
	sbq.refreshPublicSettings()
    sbq.refreshSettings()
	for k, location in pairs(Transformation.locations) do
		location.occupancy.settingsDirty = true
	end
end

sbq.groupedSettingChanged = {}
function sbq.groupedSettingChanged.locations(name,k,v)
    local location = Transformation:getLocation(name)
	if location then
		location.occupancy.settingsDirty = true
	end
end

function sbq.tryVore(target, locationName, throughput)
	local size = sbq.getEntitySize(target)
	if throughput then
		if (size) >= (throughput * sbq.size()) then return false, "tooBig" end
	end
	local location = Transformation:getLocation(locationName)
	local space, subLocation = location:hasSpace(size)
	if space then
		if Occupants.addOccupant(target, size, locationName, subLocation) then
			sbq.lockActions = true
			return true, function ()
				sbq.lockActions = false
			end
		else
			return false, "noSlots"
		end
	else
		return false, "noSpace"
	end
end

function sbq.tryLetout(target, throughput)
	local occupant = Occupants.entityId[tostring(target)]
	if not occupant then return false end
	if throughput then
		if (occupant.size * occupant.sizeMultiplier) >= (throughput * sbq.size()) then return false end
	end
	occupant.sizeMultiplier = 0 -- so belly expand anims start going down right away
	occupant:getLocation().occupancy.sizeDirty = true
	sbq.lockActions = true
	return true, function()
		sbq.lockActions = false
		occupant:remove()
	end
end

function sbq.moveToLocation(target, throughput, locationName, subLocationName)
	if not target or not locationName then return false end
	occupant = Occupants.entityId[tostring(target)]
	if not occupant then return false end
	if throughput then
		if (occupant.size * occupant.sizeMultiplier) >= (throughput * sbq.size()) then return false end
	end
	local location = Transformation:getLocation(locationName, subLocationName)
	local space, subLocationName = location:hasSpace(occupant.size * occupant.sizeMultiplier, subLocationName)
	if space then
		occupant:refreshLocation(locationName, subLocationName)
		return true
	end
	return false, "noSpace"
end

-- transformation handling
function _Transformation:getLocation(...)
	return self.state:getLocation(...)
end

function _Transformation:tryAction(action, target, ...)
	return self.state:tryAction(action, target, ...)
end

function _Transformation:actionAvailable(action, target, ...)
	return self.state:actionAvailable(action, target, ...)
end

function _Transformation:requestAction(action, target, consent, ...)
	return self.state:requestAction(action, target, consent, ...)
end

function _Transformation:doAnimations(...)
	return self.state:doAnimations(...)
end

function _Transformation:checkAnimations(...)
	return self.state:checkAnimations(...)
end

function _Transformation:interact(...)
	return self.state:interact(...)
end

function _Transformation:emergencyEscape(...)
	return self.state:emergencyEscape(...)
end

function _Transformation:changeState(stateName)
	local state = self.states[stateName]
	if not state then sbq.logError("Attempt to switch to invalid state: " .. stateName) return false end
	if self.lockStateChanges then return false end
	if stateName == self.stateName then return false end
	storage.lastState = stateName
	self.state:uninit()
	self.stateName = stateName
	self.state = state
	self.state:init()
	return true
end

-- State Handling
function _Transformation:addState(stateName, config)
	local state = sb.jsonMerge(config, {})
	state.locations = state.locations or {}
	for k, location in pairs(self.locations) do
		state.locations[k] = state.locations[k] or {}
		for k2, subLocation in pairs(location.subLocations or {}) do
			local subLocationData = sb.jsonMerge(subLocation, state.locations[k].subLocations[k2] or {})
			subLocationData.struggleActions = subLocationData.struggleActions or {}
			for actionName, struggleAction in pairs(subLocationData.struggleActions) do
				if subLocationData.struggleActions.any and actionName ~= "any" then
					setmetatable(struggleAction, {__index = subLocationData.struggleActions.any})
				end
			end
			setmetatable(subLocationData, { __index = state.locations[k] })
			state.locations[k].subLocations[k2] = subLocationData
		end

		state.locations[k].struggleActions = state.locations[k].struggleActions or {}

		for actionName, struggleAction in pairs(state.locations[k].struggleActions) do
			if state.locations[k].struggleActions.any and actionName ~= "any" then
				setmetatable(struggleAction, {__index = state.locations[k].struggleActions.any})
			end
		end

		setmetatable(state.locations[k], { __index = location })
	end
	for actionName, action in pairs(state.actions or {}) do
		setmetatable(action, _Action)
	end
	setmetatable(state, {__index = self.transformation.states[stateName] or _State})
	self.states[stateName] = state
end

function _State:getLocation(locationName, subLocation)
	if subLocation then
		return self.locations[locationName].subLocations[subLocation]
	else
		return self.locations[locationName]
	end
end

function _State:tryAction(name, target, ...)
	local action = self.actions[name]
	if not action then return self:actionFailed(name, action, target, "missingAction", ...) end
	if sbq.lockActions then return self:actionFailed(name, action, target, "actionsLocked", ...) end
	if action.onCooldown then return self:actionFailed(name, action, target, "onCooldown", ...) end
	if action.settings and not sbq.tableMatches(action.settings, sbq.settings, true) then return self:actionFailed(name, action, target, "settingMismatch", ...) end
	if action.targetSettings then
		if not target or not world.entityExists(target) then return self:actionFailed(name, action, target, "targetMissing", ...) end
		local targetSettings = sbq.getPublicProperty(target, "sbqPublicSettings")
		if not sbq.tableMatches(action.targetSettings, targetSettings, true) then return self:actionFailed(name, action, target, "targetSettingsMismatch", ...) end
		if not action.ignoreTargetOccupants then
			local targetOccupants = world.entitiesLounging(target)
			for _, occupant in ipairs(targetOccupants or {}) do
				local occupantSettings = sbq.getPublicProperty(occupant, "sbqPublicSettings")
				if not sbq.tableMatches(action.targetSettings, occupantSettings, true) then return self:actionFailed(name, action, target, "targetPreySettingsMismatch", ...) end
			end
		end
	end
	local result1, result2 = true, false
	if action.script then
		if self[action.script] then
			result1, result2 = self[action.script](self, name, action, target, ...)
		else
			return self:actionFailed(name, action, target, "missingScript", ...)
		end
	end
	if not result1 then return self:actionFailed(name, action, target, result2, ...) end
	local longest = Transformation:doAnimations(action.animations, action.tags, target)
	local cooldown = action.cooldown or longest
	action.onCooldown = true
	sbq.timer(name.."Cooldown", cooldown, function (...)
		action.onCooldown = false
		if type(result2) == "function" then
			result2(...)
		elseif type(result2) == "string" and type(self[result2]) == "function" then
			self[result2](self, ...)
		end
	end, name, action, target, result2, ...)
	if type(result2) ~= "function" then
		return result1, result2
	end
	return result1
end

function _State:requestAction(name, target, consent, ...)
    -- TODO do stuff with checking consent here later
	if not consent then return end
	if world.entityType(entity.id()) == "player" or not sbq.settings.interactDialogue then
		Transformation:tryAction(name, target, ...)
    end
	-- TODO do stuff with dialogue here later
	Transformation:tryAction(name, target, ...)
end

function _State:actionFailed(name, action, target, reason, ...)
	local cooldown = action.failureCooldown or 0
	action.onCooldown = true
	local result1, result2  = false, false
	if action.failureScript and self[action.failureScript] then result1, result2 = self[action.failureScript](self, name, action, target, reason, ...) end
	sbq.timer(name.."Cooldown", cooldown, function (...)
		action.onCooldown = false
		if type(result2) == "function" then
			result2(...)
		elseif type(result2) == "string" and type(self[result2]) == "function" then
			self[result2](self, ...)
		end
	end, name, action, target, result2, ...)
	if type(result2) ~= "function" then
		return result1, reason, result2, ...
	end
	return result1, reason, ...
end

function _State:actionAvailable(name, target, ...)
	if not name then return false end
	local action = self.actions[name]
	if not action then return false, "missingAction" end
	if action.settings and not sbq.tableMatches(action.settings, sbq.settings, true) then return false, "settingsMismatch" end
	if target and action.targetSettings then
		if not world.entityExists(target) then return false, "targetMissing" end
		local targetSettings = sbq.getPublicProperty(target, "sbqPublicSettings")
        if not sbq.tableMatches(action.targetSettings, targetSettings, true) then return false, "targetSettingsMismatch" end
		if not action.ignoreTargetOccupants then
			local targetOccupants = world.entitiesLounging(target)
			for _, occupant in ipairs(targetOccupants or {}) do
				local occupantSettings = sbq.getPublicProperty(occupant, "sbqPublicSettings")
				if not sbq.tableMatches(action.targetSettings, occupantSettings, true) then return false, "targetPreySettingsMismatch" end
			end
		end
	end
	if action.availableScript then
		if self[action.availableScript] then
			return self[action.availableScript](self, name, action, target, ...)
		else
			return false, "missingScript"
		end
	end
	return true
end

function _State:animationTags(tags, target)
	local targetTags = {
		occupant = "occupant",
		right = sbq.facingRight and "front" or "back",
		left = sbq.facingRight and "back" or "front"
	}
	if target then
		local occupant = Occupants.entityId[tostring(target)]
		if occupant then
			targetTags.occupant = occupant.seat
		end
	end
	return sb.jsonMerge(tags or {}, targetTags)
end

function _State:doAnimations(animations, tags, target)
	tags = self:animationTags(tags, target)
	local longest = 0
	for k, v in pairs(animations or {}) do
		local state = sb.replaceTags(k, tags)
		local anim = v
		local force = false
		local reversed = false
		local waitForEnd = false
		if type(v) == "table" then
			anim, force, reversed, waitForEnd = table.unpack(v)
		end
		anim = sb.replaceTags(anim, tags)
		if animator.hasState(state, anim) then
			if not waitForEnd or animator.animationEnded(state) then
				animator.setAnimationState(state, anim, force, reversed)
				local timer = animator.animationTimer(state)
				longest = math.max(longest, timer[2] - timer[1])
			end
		end
	end
	return longest
end

function _State:checkAnimations(activeOnly, animations, tags, target)
	tags = self:animationTags(tags, target)
	local longest = 0
	for k, v in pairs(animations or {}) do
		local state = sb.replaceTags(k, tags)
		local anim = v
		if type(v) == "table" then
			anim, force, reversed, waitForEnd = table.unpack(v)
		end
		anim = sb.replaceTags(anim, tags)
		if (animator.hasState(state, anim) and not activeOnly)
		or (animator.hasState(state) and animator.animationState(state) == "anim")
		then
			local timer = animator.animationTimer(state, anim)
			longest = math.max(longest, timer[2] - timer[1])
		end
	end
	return longest
end

function _State:interact(args)
	-- find closest interaction point, 4d voronoi style
	local pos = sbq.globalToLocal(args.sourcePosition)
	local aim = sbq.globalToLocal(args.interactPosition)
	local closest = nil
	local distance = math.huge
	for _, v in pairs(self.interactActions or {}) do
		local p
		local a
		if (v.posPart or v.part) and v.pos then
			p = sbq.localPartPoint(v.posPart or v.part, v.pos)
		end
		if (v.aimPart or v.part) and v.aim then
			a = sbq.localPartPoint(v.aimPart or v.part, v.aim)
		end
		-- check if we should even consider this action
		local valid = Transformation:actionAvailable(v.action, args.sourceId, table.unpack(v.args or {}))
		-- check if there either point must be within a radius
		if valid and p and (v.posRadius or v.radius) then
			valid = ((v.posRadius or v.radius) > vec2.mag(vec2.sub(p, pos)))
		end
		if valid and a and (v.aimRadius or v.radius) then
			valid = ((v.aimRadius or v.radius) > vec2.mag(vec2.sub(a, aim)))
		end
		if valid then
			if not p and not a then
				-- no pos or aim, just make this one happen
				p = pos
				a = aim
			elseif a and not p then
				-- pos isn't specified, default to same as aim but less weight
				p = {
					(a[1] + pos[1])/2,
					(a[2] + pos[2])/2
				}
			elseif p and not a then
				-- aim isn't specified, default to same as pos but less weight
				a = {
					(p[1] + aim[1])/2,
					(p[2] + aim[2])/2
				}
			end
			local d = math.sqrt(
				(pos[1] - p[1])^2 +
				(pos[2] - p[2])^2 +
				(aim[1] - a[1])^2 +
				(aim[2] - a[2])^2
			)
			if d < distance then
				distance = d
				closest = v
			end
		end
	end
	if closest then
		Transformation:tryAction(closest.action, args.sourceId, table.unpack(closest.args or {}))
	end
end

function _State:emergencyEscape(occupant)
	world.spawnProjectile("sbqMemeExplosion", occupant:position())
	occupant:remove()
end


-- Location handling
function _Transformation:addLocation(name, config)
	local location = sb.jsonMerge(sbq.config.defaultLocationData, sbq.config.locations[name] or {}, root.fetchConfigArray(config, sbq.directory()))
	location.tag = name
	location.key = name
	location.name = location.name or (":"..name)
	-- if infusion is enabled and someone is in the slot then modify the properties of that location accordingly
	if location.infusionSlot and sbq.settings[location.infusionType .. "Pred"] and sbq.settings[location.infusionSlot] then
		local infused = sbq.settings[location.infusionSlot]
		local species = infused.parameters.npcArgs.npcSpecies
		local voreConfig = root.fetchConfigArray(infused.parameters.voreConfig or root.speciesConfig(species).voreConfig or "/humanoid/any/vore.config", sbq.directory())
		location = sb.jsonMerge(sbq.config.locations[name],
			{ species = voreConfig.tfSpecies or species },
			root.fetchConfigArray(
				sb.jsonQuery(voreConfig, "infusedLocations." .. species .. "." .. name) or
				sb.jsonQuery(voreConfig, "infusedLocations." .. name) or {},
			sbq.directory())
		)
		-- certain NPCs may not like performing certain actions, therefore they can disable them when infused
		local metatable = getmetatable(sbq.settings)
		sbq.settings = sb.jsonMerge(sbq.settings, root.fetchConfigArray(infused.parameters.overrideSettings or {}, infused.parameters.relativePath or sbq.directory()),
			root.fetchConfigArray(sb.jsonQuery(infused.parameters, "conditionalOverrideSettings." .. species .. "." .. name)
				or sb.jsonQuery(infused.parameters, "conditionalOverrideSettings." .. name) or {}, infused.parameters.relativePath or sbq.directory()))
		setmetatable(sbq.settings, metatable)
	end
	-- easier to make it default to math.huge than have it check if it's defined or not
	location.maxFill = location.maxFill or math.huge
	-- setup occupancy values
	location.occupancy = {
		sizeDirty = true,
		settingsDirty = true,
		list = {},
		size = 0,
		visualSize = -1,
		interpolating = false,
		struggleVec = {0,0},
		interpolateFrom = 0,
		interpolateTime = 0,
		subLocations = {}
	}
	-- sub locations are for things that are different spots techincally, but inherit values and use the settings
	-- of a single location, such as with the sidedness of breasts, or perhaps a multi chambered stomach
	for k, subLocation in pairs(location.subLocations or {}) do
		subLocation.occupancy = {
			sizeDirty = true,
			settingsDirty = true,
			list = {},
			size = 0,
			visualSize = -1,
			interpolating = false,
			interpolateFrom = 0,
			interpolateTime = 0,
		}
		if k == "<left>" or k == "<right>" then
			subLocation.occupancy.sided = true
			subLocation.occupancy.facingRight = sbq.facingRight
		end
		subLocation.tag = name .. k
		subLocation.subKey = k
		location.occupancy.subLocations[k] = subLocation.occupancy
		setmetatable(subLocation, {__index = location})
	end

	Occupants.locations[name] = location.occupancy
	location.settings = {}
	setmetatable(location.settings, {__index = sbq.settings.locations[location.settingsTable or name]})
	setmetatable(location, {__index = self.transformation.locations[name] or _Location})
	self.locations[name] = location
end

function _Location:hasSpace(size, subLocation)
	if not sbq.tableMatches(self.activeSettings, sbq.settings, true) then return false end
	if self.maxCount and (#self.occupancy.list >= self.maxCount) then return false end
	if self.settings.hammerspace then return math.huge end
	local shared = 0
	for _, name in ipairs(self.sharedWith or {}) do
		local location = Transformation:getLocation(name)
		shared = shared + location.occupancy.size
	end
	if not self.subLocations then
		return self:getRemainingSpace(self.maxFill, self.occupancy.size + shared, size)
	elseif subLocation then
		if self.subLocations[subLocation].maxCount and (#self.occupancy.subLocations[subLocation].list >= self.subLocations[subLocation].maxCount) then return false end
		-- if we got an input for a sublocation, check that specific one and return
		return self:getRemainingSpace(self.subLocations[subLocation].maxFill, self.occupancy.subLocations[subLocation].size + shared, size), subLocation
	elseif self.subLocations[1] then
		if self.subLocations[1].maxCount and (#self.occupancy.subLocations[1].list >= self.subLocations[1].maxCount) then return false end
		-- if an array, assuming locations are ordered, only check if theres space in the first
		return self:getRemainingSpace(self.subLocations[1].maxFill, self.occupancy.subLocations[1].size + shared, size), 1
	else
		-- if an object assume any is valid and choose one with the most space available
		local best = {0}
		for k, v in pairs(self.subLocations) do
			if not (v.maxCount and (#v.occupancy.list >= v.maxCount)) then
				local space = self:getRemainingSpace(v.maxFill, v.occupancy.size, size)
				if space and space > best[1] then
					best = {space, k}
				end
			end
		end
		if best[2] then
			return best[1], best[2]
		end
	end
	return false
end
function _Location:getRemainingSpace(maxFill, occupancy, size)
	local remainingSpace = maxFill - (occupancy + (size or 0))
	if remainingSpace < 0 then return false end
	return remainingSpace
end

function _Location:updateOccupancy(dt, subLocationBehavior)
	local directionTags = {
		right = sbq.facingRight and "front" or "back",
		left = sbq.facingRight and "back" or "front"
	}
	local prevVisualSize = self.occupancy.visualSize
	if self.occupancy.sizeDirty or self.occupancy.settingsDirty or (Occupants.lastScale ~= sbq.scale()) then
		self.occupancy.sizeDirty = false
		self.occupancy.size = (self.settings.visualMinAdd and self.settings.visualMin) or 0
		if subLocationBehavior then
			if subLocationBehavior == "average" then
				local total = 0
				local amount = 0
				for _, subLocation in pairs(self.subLocations) do
					total = subLocation.occupancy.size + total
					amount = amount + 1
				end
				self.occupancy.size = (total / amount)
			elseif subLocationBehavior == "largest" then
				local best = 0
				for _, subLocation in pairs(self.subLocations) do
					best = math.max(best, subLocation.occupancy.size)
				end
				self.occupancy.size = self.occupancy.size + best
			elseif subLocationBehavior == "smallest" then
				local best = self.maxFill
				for _, subLocation in pairs(self.subLocations) do
					best = math.min(best, subLocation.occupancy.size)
				end
				self.occupancy.size = self.occupancy.size + best
			end
		else
			for _, occupant in ipairs(self.occupancy.list) do
				self.occupancy.size = self.occupancy.size + (occupant.size * occupant.sizeMultiplier / sbq.size())
			end
			self.occupancy.size = math.min(math.max(self.settings.visualMin, self.occupancy.size), self.settings.visualMax)
			local addVisual = 0
			for _, name in ipairs(self.addFill or {}) do
				local location = Transformation:getLocation(name)
				location:updateOccupancy(0, name, location.subLocationBehavior)
				addVisual = addVisual + location.occupancy.visualSize
			end
			self.occupancy.visualSize = sbq.getClosestValue(self.occupancy.size + addVisual, self.struggleSizes or { 0 })
		end
		if (prevVisualSize ~= self.occupancy.visualSize) and not (self.occupancy.sided and (self.symmertySettings and sbq.tableMatches(self.symmertySettings, sbq.settings, true))) then
			local interpolateAnims = self.occupancy.queuedInterpolateAnims or self.interpolateAnims
			if interpolateAnims then
				self.occupancy.interpolating = true
				self.occupancy.interpolateFrom = self.occupancy.interpolateSize or prevVisualSize
				self.interpolateTime = Transformation:doAnimations(interpolateAnims)
				self.interpolateCurTime = 0
			end
			self.occupancy.queuedInterpolateAnims = nil
			animator.setGlobalTag(sb.replaceTags(self.tag, directionTags) .. "_occupants", tostring(self.occupancy.visualSize))
			if self.subLocations and (self.symmertySettings and sbq.tableMatches(self.symmertySettings or {}, sbq.settings, true)) then
				for _, subLocation in pairs(self.subLocations) do
					animator.setGlobalTag(sb.replaceTags(subLocation.tag, directionTags) .. "_occupants", tostring(self.occupancy.visualSize))
				end
			end
		end
	end
	if self.occupancy.sided and (self.occupancy.facingRight ~= sbq.facingRight) and not (self.symmertySettings and sbq.tableMatches(self.symmertySettings, sbq.settings, true)) then
		animator.setGlobalTag(sb.replaceTags(self.tag, directionTags).."_occupants", tostring(self.occupancy.visualSize))
	end
	if self.occupancy.interpolating then
		self.interpolateCurTime = self.interpolateCurTime + dt
		self.occupancy.interpolateSize = sbq.getClosestValue(
			interp.linear(
				self.interpolateCurTime / self.interpolateTime,
				self.occupancy.interpolateFrom,
				self.occupancy.visualSize
			),
			self.interpolateSizes or self.struggleSizes or {0}
		)
		if self.occupancy.interpolateSize == self.occupancy.visualSize then self.occupancy.interpolating = false end
		animator.setGlobalTag(sb.replaceTags(self.tag, directionTags).."_occupantsInterpolate", tostring(self.occupancy.interpolateSize))
		if self.subLocations and (self.symmertySettings and sbq.tableMatches(self.symmertySettings or {}, sbq.setting, true)) then
			for _, subLocation in pairs(self.subLocations) do
				animator.setGlobalTag(sb.replaceTags(subLocation.tag, directionTags) .. "_occupants", tostring(self.occupancy.visualSize))
			end
		end
	end
end

function _Location:refreshStruggleDirection(id)
	self.occupancy.struggleVec = {0,0}
	for _, occupant in ipairs(self.occupancy.list) do
		occupant:checkStruggleDirection(0)
		self.occupancy.struggleVec = vec2.add(self.occupancy.struggleVec, occupant.struggleVec)
	end
	for _, locationName in ipairs(self.sharedWith or {}) do
		local location = Transformation:getLocation(locationName)
		for _, occupant in ipairs(location.occupancy.list) do
			occupant:checkStruggleDirection(0)
			self.occupancy.struggleVec = vec2.add(self.occupancy.struggleVec, occupant.struggleVec)
		end
	end
	local newVec = self.occupancy.struggleVec
	local oldAction = self.occupancy.struggleAction
	local oldDirection = self.occupancy.struggleDirection
	local newDirection
	-- check if struggle direction anims should change
	if math.abs(newVec[1]) > math.abs(newVec[2]) then
		-- left/right struggle
		if newVec[1] < 0 then -- left struggle
			newDirection = "left"
		elseif newVec[1] > 0 then -- right struggle
			newDirection = "right"
		end
	else
		-- up down struggle
		if newVec[2] < 0 then -- left struggle
			newDirection = "down"
		elseif newVec[2] > 0 then -- right struggle
			newDirection = "up"
		end
	end
	local struggleAction, direction = self:getStruggleAction(newDirection)
	if direction ~= oldDirection then
		self.occupancy.struggleDirection = direction
		self.occupancy.struggleAction = struggleAction
		local newAnims = {}
		if struggleAction then
			newAnims = struggleAction.pressAnimations or struggleAction.holdAnimations or {}
		end
		if oldDirection and oldAction then
			if oldAction.releaseAnimations then
				local delay = Transformation:doAnimations(oldAction.releaseAnimations or {}, { s_direction = oldDirection }, id)
				sbq.forceTimer(self.tag.."StruggleChange", delay, function ()
					Transformation:doAnimations(newAnims, { s_direction = oldDirection }, id)
				end)
				return Transformation:checkAnimations(false, newAnims, { s_direction = direction }, id) + delay, direction
			end
		end
		return Transformation:doAnimations(newAnims, { s_direction = direction }, id), direction
	end
	return 0, direction
end
function _Location:getStruggleAction(direction)
	if not direction then return end
	direction = string.lower(direction)
	local newDirection = direction
	if direction == "left" then
		newDirection = sbq.facingRight and "back" or "front"
	elseif direction == "right" then
		newDirection = sbq.facingRight and "front" or "back"
	end
	if self.struggleActions[direction] then
		return self.struggleActions[direction], newDirection
	end
	return self.struggleActions[newDirection], newDirection
end

function _Location:outputData(entityId)
	local merge = {}
	table.insert(merge, Transformation.locations[self.key] or {})
	if self.subKey then
		table.insert(merge, Transformation.locations[self.key].subLocations[self.subKey] or {})
	end
	table.insert(merge, Transformation.state.locations[self.key] or {})
	if self.subKey then
		table.insert(merge, Transformation.state.locations[self.key].subLocations[self.subKey] or {})
	end
	local location = sb.jsonMerge(table.unpack(merge))
	location.occupancy = nil
	location.settings = nil
	for _, struggleAction in pairs(location.struggleActions or {}) do
		if not Transformation:actionAvailable(struggleAction.action, entityId, table.unpack(struggleAction.args or {})) then
			struggleAction.indicate = "default"
		end
	end
	return location
end

-- Occupant Handling
function Occupants.addOccupant(entityId, size, location, subLocation)
	-- check if we already have them
    local occupant = Occupants.entityId[tostring(entityId)]
    if occupant then
		occupant:refreshLocation(location, subLocation)
		return true
	end
	local seat
	-- check for unoccupied occupant seat
	for i = 0, sbq.config.seatCount - 1 do
		if not loungeable.entityLoungingIn("occupant"..i) then
			seat = "occupant"..i
			break
		end
	end
	-- -- if in the future we ever can have dynamic animation parts and seats
	-- local occupantAnim = sbq.replaceConfigTags(
	-- 	root.fetchConfigArray(sbq.voreConfig.occupantAnimationConfig or "/humanoid/any/voreOccupant.animation"),
	-- 	{occupant = seat}
	-- )

	-- if there is no available seat we cannot add the occupant
	if not seat then return false end
	-- setup occupant values
	local occupant = {
		entityId = entityId,
		seat = seat,
		flags = {},
		location = nil,
		subLocation = nil,
		size = size or 1,
		sizeMultiplier = 1,
		struggleGracePeriod = 0,
		time = 0,
		struggleTime = 0,
		struggleCount = 0,
		struggleVec = {0,0},
		locationStore = {},
		progressBar = nil,
	}
	setmetatable(occupant, _Occupant)
	-- add occupant to tables for easily referencing it
	table.insert(Occupants.list, occupant)
	Occupants.seat[seat] = occupant
	Occupants.entityId[tostring(entityId)] = occupant
	local uuid = world.entityUniqueId(entityId)
	if uuid then
		Occupants.entityId[uuid] = occupant
	end
	-- refresh the location data for this occupant
	occupant:refreshLocation(location, subLocation)
	occupant:setLoungeEnabled(true)
	occupant:setDismountable(false)
	world.sendEntityMessage(entityId, "sbqForceSit", { index = occupant:getLoungeIndex(), source = entity.id() })
	return true
end

function _Occupant:remove()
	self:setLoungeEnabled(false)
	local location = Transformation:getLocation(self.location)

	Occupants.seat[self.seat] = nil

	if self.subLocation then
		local subLocation = Transformation:getLocation(self.location, self.subLocation)
		for i, occupant in ipairs(subLocation.occupancy.list) do
			if occupant.entityId == self.entityId then
				subLocation.occupancy.sizeDirty = true
				table.remove(subLocation.occupancy.list, i)
				break
			end
		end
	end
	for i, occupant in ipairs(location.occupancy.list) do
		if occupant.entityId == self.entityId then
			location.occupancy.sizeDirty = true
			table.remove(location.occupancy.list, i)
			break
		end
	end
	for i, occupant in ipairs(Occupants.list) do
		if occupant.entityId == self.entityId then
			table.remove(Occupants.list, i)
			break
		end
	end
	for k, occupant in pairs(Occupants.entityId) do
		if occupant.entityId == self.entityId then
			Occupants.entityId[k] = nil
		end
    end
	Occupants.refreshOccupantModifiers = true
	world.sendEntityMessage(entity.id(), "sbqRefreshHudOccupants", Occupants.list)
end

function Occupants.update(dt)
	for name, _ in pairs(Transformation.locations) do
		local location = Transformation:getLocation(name)
		for k, v in pairs(location.subLocations or {}) do
			local subLocation = Transformation:getLocation(name, k)
			location.occupancy.sizeDirty = subLocation.occupancy.sizeDirty or location.occupancy.sizeDirty
			location.occupancy.settingsDirty = subLocation.occupancy.settingsDirty or location.occupancy.settingsDirty
			subLocation.occupancy.settingsDirty = subLocation.occupancy.settingsDirty or location.occupancy.settingsDirty
			subLocation:updateOccupancy(dt)
		end
		location:updateOccupancy(dt, location.subLocationBehavior)
    end
	for _, occupant in ipairs(Occupants.list) do
		occupant:update(dt)
	end
    for name, _ in pairs(Transformation.locations) do
		local location = Transformation:getLocation(name)
		for k, _ in pairs(location.subLocations or {}) do
			local subLocation = Transformation:getLocation(name, k)
			subLocation.occupancy.settingsDirty = false
		end
		location.occupancy.settingsDirty = false
	end
	Occupants.lastScale = sbq.scale()

    if Occupants.refreshOccupantModifiers then
        Occupants.refreshOccupantModifiers = false
		local modifiers = {}
        for _, occupant in ipairs(Occupants.list) do
			util.appendLists(modifiers, occupant.predModifiers or {})
        end
		sbq.setStatModifiers("occupantModifiers", modifiers)
	end
end

function _Occupant:update(dt)
	if not world.entityExists(self.entityId) then self:remove() end
	local location = self:getLocation()
	if location.occupancy.settingsDirty then self:refreshLocation() end
	if not animator.animationEnded(self.seat .. "State") then
		self:setHidden(animator.partProperty(self.seat, "hidden"))
		self:setLoungeDance(animator.partProperty(self.seat, "dance"))
		self:setLoungeEmote(animator.partProperty(self.seat, "emote"))
	end
	local locationStore = self.locationStore[self.location]

	locationStore.time = locationStore.time + dt
	self.time = self.time + dt
	if self.progressBar then
		self.progressBar.progress = self.progressBar.progress + (dt * (self.progressBar.args.speed or 1))
		if self.progressBar.progress >= 100 then self.progressBar.callback(self, self.progressBar.args) end
	end

	if not self.flags.digested then
		local oldMultiplier = self.sizeMultiplier
		local compression = location.settings.compression
		local compressionMin = location.settings.compressionMin
		if compression == "time" then
			self.sizeMultiplier = math.max( compressionMin, self.sizeMultiplier - (sbq.stat("sbqDigestPower") * dt * sbq.config.compressionRate))
		elseif compression == "health" then
			self.sizeMultiplier = math.max( compressionMin, world.entityResourcePercentage(self.entityId, "health"))
		end
		if oldMultiplier ~= self.sizeMultiplier then
			location.occupancy.sizeDirty = true
		end
	end
	self:checkStruggleDirection(dt)
end

function _Occupant:refreshLocation(name, subLocation)
	local location = self:getLocation()

	if (name and (self.location ~= name)) or (subLocation and (self.subLocation ~= subLocation)) then
		location.occupancy.sizeDirty = true
		for i, occupant in ipairs(location.occupancy.list) do
			if occupant.entityId == self.entityId then
				table.remove(location.occupancy.list, i)
				break
			end
		end
		self.location = name
		self.subLocation = subLocation
		location = self:getLocation()

		table.insert(location.occupancy.list, self)
		location.occupancy.sizeDirty = true
		for _, sharedName in ipairs(location.sharedWith or {}) do
			local shared = Transformation:getLocation(sharedName)
			shared.occupancy.sizeDirty = true
		end
	end
	if not sbq.tableMatches(location.activeSettings, sbq.settings, true) then return self:remove() end

	local attemptAnims = {
		Transformation.stateName .. "_" .. location.tag .. "_" .. location.occupancy.visualSize,
		Transformation.stateName .. "_" .. location.tag,
		location.tag .. "_" .. location.occupancy.visualSize,
		location.tag,
		self.location .. "_" .. location.occupancy.visualSize,
		self.location
	}
	for _, v in ipairs(attemptAnims) do
		if animator.hasState(self.seat .. "Location", v) then
			animator.setAnimationState(self.seat.."Location", v)
		end
	end

	if not self.locationStore[self.location] then
		self.locationStore[self.location] = {
			time = 0,
			struggleTime = 0
		}
	end

	local persistentStatusEffects = {
		{ stat = "sbqDigestingPower", amount = sbq.stat(location.powerMultiplier or "powerMultiplier") },
        { stat = "sbqGetDigestDrops", amount = location.settings.getDigestDrops and 1 or 0 },
        { stat = "sbqDisplayEffect", amount = sbq.settings.displayEffect and 1 or 0 },

	}
	util.appendLists(persistentStatusEffects, sbq.voreConfig.prey.statusEffects or sbq.config.prey.statusEffects)
    util.appendLists(persistentStatusEffects, location.passiveEffects or {})
	if not (self.flags.digested or self.flags.infused) then
		util.appendLists(persistentStatusEffects, (location.mainEffect or {})[self.overrideEffect or location.settings.mainEffect or "none"] or {})
		for setting, effects in pairs(location.toggleEffects or {}) do
			if (location.settings[setting]) then
				util.appendLists(persistentStatusEffects, effects or {})
			end
		end
	end
    local predModifiers = {}
	local preyModifiers = {}

	for _, effect in ipairs(persistentStatusEffects) do
		if type(effect) == "string" then
            local effectConfig = root.effectConfig(effect).effectConfig or {}
			if effectConfig.predModifiers then
				util.appendLists(predModifiers, effectConfig.predModifiers)
            end
			if effectConfig.preyModifiers then
				util.appendLists(preyModifiers, effectConfig.preyModifiers)
            end
			if effectConfig.predStatModifiers then
				util.appendLists(predModifiers, sbq.getModifiers(effectConfig.predStatModifiers, sbq.stat(location.powerMultiplier or "powerMultiplier")))
			end
			if effectConfig.preyStatModifiers then
				util.appendLists(preyModifiers, sbq.getModifiers(effectConfig.preyStatModifiers, sbq.stat(location.powerMultiplier or "powerMultiplier")))
			end
		end
    end
	util.appendLists(persistentStatusEffects, preyModifiers)
    self:setLoungeStatusEffects(persistentStatusEffects)
	self.predModifiers = predModifiers
    Occupants.refreshOccupantModifiers = true

	self:setItemBlacklist(location.itemBlacklist or sbq.voreConfig.prey.itemBlacklist or sbq.config.prey.itemBlacklist)
	self:setItemWhitelist(location.itemWhitelist or sbq.voreConfig.prey.itemWhitelist or sbq.config.prey.itemWhitelist)
	self:setItemTagBlacklist(location.itemTagBlacklist or sbq.voreConfig.prey.itemTagBlacklist or sbq.config.prey.itemTagBlacklist)
	self:setItemTagWhitelist(location.itemTagWhitelist or sbq.voreConfig.prey.itemTagWhitelist or sbq.config.prey.itemTagWhitelist)
	self:setItemTypeBlacklist(location.itemTypeBlacklist or sbq.voreConfig.prey.itemTypeBlacklist or sbq.config.prey.itemTypeBlacklist)
	self:setItemTypeWhitelist(location.itemTypeWhitelist or sbq.voreConfig.prey.itemTypeWhitelist or sbq.config.prey.itemTypeWhitelist)
	self:setToolUsageSuppressed(location.toolUsageSuppressed or sbq.voreConfig.prey.toolUsageSuppressed or sbq.config.prey.toolUsageSuppressed)

	world.sendEntityMessage(self.entityId, "sbqRefreshLocationData", entity.id(), location:outputData(self.entityId), {
		progressBar = self.progressBar,
		time = self.time,
    })
    world.sendEntityMessage(entity.id(), "sbqGuiMessage", "sbqRefreshHudOccupants", Occupants.list)
end

function sbq.getModifiers(modifiers, power)
	local output = {}
	for k, v in pairs(modifiers) do
        local modifier = { stat = k }
		if v.op == "div" then
            modifier[v.type] = 1 / math.max(power * (v.base or 1), 1)
		elseif v.op == "sub" then
            modifier[v.type] = 1 - (power * (v.base or 1))
        elseif v.op == "mul" then
            modifier[v.type] = math.max(power * (v.base or 1), 1)
		elseif v.op == "add" then
			modifier[v.type] = (power * (v.base or 1))
        end
		table.insert(output, modifier)
    end
	return output
end

function _Occupant:attemptStruggle(control)
	local location = self:getLocation()
	local bonusTime = 0
	local maybeBonus, locationDirection = location:refreshStruggleDirection(self.entityId)
	local struggleAction, direction = location:getStruggleAction(control)
	if locationDirection == direction then
		bonusTime = bonusTime + maybeBonus
	end
	if struggleAction then
		self.struggleAction = struggleAction
		self.struggleDirection = direction
		if struggleAction.pressAnimations and not struggleAction.holdAnimations then
			bonusTime = bonusTime + Transformation:doAnimations(struggleAction.pressAnimations, {s_direction = direction}, self.entityId)
		end
		if (bonusTime > 0) then
			if not self:overConsumeResource("energy", sbq.config.struggleCost) then return end
		end
		self:tryStruggleAction((bonusTime > 0) and 1 or 0, bonusTime)
	end
end
function _Occupant:releaseStruggle(control, time)
	local location = self:getLocation()
	location:refreshStruggleDirection(self.entityId)
end

function _Occupant:getLocation()
	if not self.location then return sb.jsonMerge(sbq.config.defaultLocationData, {}) end
	return Transformation:getLocation(self.location, self.subLocation)
end


function _Occupant:checkStruggleDirection(dt)
	local dx = 0
	local dy = 0
	local effectiveness = self.sizeMultiplier * self.size
	local staleTime = 5
	if self:controlHeld("Up") then
		dy = dy + 1
		-- if self:controlHeldTime("Up") > staleTime then effectiveness = effectiveness * 0.5 end
	end
	if self:controlHeld("Down") then
		dy = dy - 1
		-- if self:controlHeldTime("Down") > staleTime then effectiveness = effectiveness * 0.5 end
	end
	if self:controlHeld("Left") then
		dx = dx - 1
		-- if self:controlHeldTime("Left") > staleTime then effectiveness = effectiveness * 0.5 end
	end
	if self:controlHeld("Right") then
		dx = dx + 1
		-- if self:controlHeldTime("Right") > staleTime then effectiveness = effectiveness * 0.5 end
	end
	self.struggleVec = {dx * effectiveness, dy * effectiveness}
	if (dx ~= 0 or dy ~= 0) then
		self.struggleTime = self.struggleTime + (dt * effectiveness)
		self.locationStore[self.location].struggleTime = self.locationStore[self.location].struggleTime + dt
		if not self:consumeResource("energy", sbq.config.struggleCost * dt, true) then return end
		self.struggleGracePeriod = sbq.config.struggleGracePeriod * effectiveness
		if sbq.timer(self.seat.."StruggleActionCooldown", 1) and dt ~= 0 then
			self:tryStruggleAction(0,0)
		end
	else
		if self.struggleGracePeriod <= 0 then
			if self.struggleTime <= 0 then
				self.struggleCount = 0
			else
				self.struggleTime = self.struggleTime - dt
			end
		else
			self.struggleGracePeriod = self.struggleGracePeriod - dt
		end
	end
end

function _Occupant:tryStruggleAction(inc, bonusTime)
	if (not self.struggleAction) or (self:controlHeld("Shift")) then return false end
	locationStore = self.locationStore[self.location]
	if self.struggleAction.holdAnimations and not self.struggleAction.pressAnimations then
		Transformation:doAnimations(self.struggleAction.holdAnimations or {}, {s_direction = self.struggleDirection})
	end
	self.struggleTime = (self.struggleTime or 0) + bonusTime
	self.struggleCount = (self.struggleCount or 0) + inc
	locationStore = (locationStore.struggleCount or 0) + inc
	if self.struggleAction.action then
		local timeSucceeded = self.struggleTime >= math.random(table.unpack(self.struggleAction.time or { 0, 0 }))
		local countSucceeded = self.struggleCount >= math.random(table.unpack(self.struggleAction.count or { 0, 0 }))
		if (self.struggleAction.both and (timeSucceeded and countSucceeded))
		or (not self.struggleAction.both and (timeSucceeded or countSucceeded))
		then
			Transformation:tryAction(self.struggleAction.action, self.entityId, table.unpack(self.struggleAction.args or {}))
		end
	end
end

function _Occupant:setProgressBar(name, args, callback, progress)
	self.progressBar.progress = progress or 0
	self.progressBar.args = args
	self.progressBar.name = name
	self.progressBar.callback = callback

	world.sendEntityMessage(self.entityId, "sbqRefreshLocationData", entity.id(), self:getLocation():outputData(self.entityId), {
		progressBar = self.progressBar,
		time = self.time,
	})
end
function _Occupant:controlPressed(control, time)
	if control == "Jump" then
		if self:controlHeld("Left") and self:controlHeld("Right") then
			Transformation:emergencyEscape(self)
			return
        end
    elseif control == "Interact" then
		self:sendEntityMessage("sbqInteractWith", entity.id())
		return
	end
	self:attemptStruggle(control)
end
function _Occupant:controlReleased(control, time)
	self:releaseStruggle(control)
end

function _Occupant:consumeResource(resource, amount, ignoreBlock)
	-- if an entity doesn't have the resource, they get to have it for free
	if not world.entityIsResource(self.entityId, resource) then return true end
	if (world.entityResource(self.entityId, resource) >= amount) and ignoreBlock or not world.entityResourceLocked(self.entityId, resource) then
		world.sendEntityMessage(self.entityId, "sbqOverConsumeResource", resource, amount, ignoreBlock)
		return true
	end
	return false
end
function _Occupant:consumeResource(resource, amount, ignoreBlock)
	-- if an entity doesn't have the resource, they get to have it for free
	if not world.entityIsResource(self.entityId, resource) then return true end
	if (world.entityResource(self.entityId, resource) >= amount) and ignoreBlock or not world.entityResourceLocked(self.entityId, resource) then
		world.sendEntityMessage(self.entityId, "sbqOverConsumeResource", resource, amount, ignoreBlock)
		return true
	end
	return false
end
function _Occupant:overConsumeResource(resource, amount, ignoreBlock)
	-- if an entity doesn't have the resource, they get to have it for free
	if not world.entityIsResource(self.entityId, resource) then return true end
	if (world.entityResource(self.entityId, resource) > 0) and ignoreBlock or not world.entityResourceLocked(self.entityId, resource) then
		world.sendEntityMessage(self.entityId, "sbqOverConsumeResource", resource, amount, ignoreBlock)
		return true
	end
	return false
end

function _Occupant:stat(stat)
	return world.entityStat(self.entityId, stat)
end
function _Occupant:statPositive(stat)
	return world.entityStatPositive(self.entityId, stat)
end

function _Occupant:sendEntityMessage(...)
	return world.sendEntityMessage(self.entityId, ...)
end

function _Occupant:position()
	return sbq.globalPartPoint(self.seat, "loungeOffset")
end
function _Occupant:localPosition()
	return sbq.localPartPoint(self.seat, "loungeOffset")
end
function _Occupant:controlHeld(...)
	return loungeable.controlHeld(self.seat, ...)
end
function _Occupant:controlHeldTime(...)
	return loungeable.controlHeldTime(self.seat, ...)
end
function _Occupant:aimPosition(...)
	return loungeable.aimPosition(self.seat, ...)
end
function _Occupant:entityLoungingIn(...)
	return loungeable.entityLoungingIn(self.seat, ...)
end
function _Occupant:setLoungeEnabled(...)
	return loungeable.setLoungeEnabled(self.seat, ...)
end
function _Occupant:setLoungeOrientation(...)
	return loungeable.setLoungeOrientation(self.seat, ...)
end
function _Occupant:setLoungeEmote(...)
	return loungeable.setLoungeEmote(self.seat, ...)
end
function _Occupant:setLoungeDance(...)
	return loungeable.setLoungeDance(self.seat, ...)
end
function _Occupant:setLoungeDirectives(...)
	return loungeable.setLoungeDirectives(self.seat, ...)
end
function _Occupant:setLoungeStatusEffects(...)
	return loungeable.setLoungeStatusEffects(self.seat, ...)
end
function _Occupant:setToolUsageSuppressed(...)
	return loungeable.setToolUsageSuppressed(self.seat, ...)
end
function _Occupant:setDismountable(...)
	return loungeable.setDismountable(self.seat, ...)
end
function _Occupant:setHidden(...)
	return loungeable.setHidden(self.seat, ...)
end
function _Occupant:setItemBlacklist(...)
	return loungeable.setItemBlacklist(self.seat, ...)
end
function _Occupant:setItemWhitelist(...)
	return loungeable.setItemWhitelist(self.seat, ...)
end
function _Occupant:setItemTagBlacklist(...)
	return loungeable.setItemTagBlacklist(self.seat, ...)
end
function _Occupant:setItemTagWhitelist(...)
	return loungeable.setItemTagWhitelist(self.seat, ...)
end
function _Occupant:setItemTypeBlacklist(...)
	return loungeable.setItemTypeBlacklist(self.seat, ...)
end
function _Occupant:setItemTypeWhitelist(...)
	return loungeable.setItemTypeWhitelist(self.seat, ...)
end
function _Occupant:getLoungeIndex()
	return loungeable.getIndexFromName(self.seat)
end

function _Occupant:logInfo(json)
	sbq.logInfo("["..self.seat.."]["..world.entityName(self.entityId).."]"..tostring(json))
end
function _Occupant:logError(json)
	sbq.logError("["..self.seat.."]["..world.entityName(self.entityId).."]"..tostring(json))
end
