require "/scripts/util.lua"
require "/scripts/SBQ_util.lua"

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
Transformation = {}

States = {}

Locations = {locations = {}}

Occupants = {
	list = {},
	seat = {},
	entityId = {},
	locations = {}
}

function controlPressed(seat, control, time)
	if Occupants.seat[seat] then Occupants.seat[seat]:controlPressed(control, time) end
	sb.logInfo("Pressed:"..sb.printJson({seat,control,time}))
end
function controlReleased(seat, control, time)
	if Occupants.seat[seat] then Occupants.seat[seat]:controlReleased(control, time) end
	sb.logInfo("Released:"..sb.printJson({seat,control,time}))
end

function sbq.init()
	message.setHandler("sbqAddOccupant", function (_,_, ...)
		Occupants.addOccupant(...)
	end)
    message.setHandler("sbqTryAction", function(_, _, ...)
		sbq.tryAction(...)
	end)
    sbq.reloadVoreConfig(storage.lastVoreConfig)
end

function sbq.update(dt)
	Occupants.update(dt)
	if Transformation.active then
		Transformation:update(dt)
		Transformation.state:update(dt)
	end
end

function sbq.uninit()
	if Transformation.active then
		Transformation:uninit()
		Transformation.state:uninit()
		Transformation.active = false
	end
end

function sbq.reloadVoreConfig(config)
	-- if reloading while another transformation is already active, uninitialize it first
	if Transformation.active then
		Transformation.state:uninit()
		Transformation:uninit()
		Transformation.active = false
    end
	-- store the last input so it's used again on the next initiaization
	storage.lastVoreConfig = config

	-- load config from species or config input, such as from a tech transformation
    sbq.voreConfig = sbq.getConfigArray(config or root.speciesConfig(humanoid.species()).voreConfig or "/humanoid/any/vore.config")
	-- reset setting tables on reload
	sbq.setupSettingMetatables(entity.entityType())

	-- load scripts
	for _, script in ipairs(sbq.voreConfig.scripts or {}) do
		require(script)
	end
	Transformation = Transformations[sbq.voreConfig.transformation or "default"]

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
	Locations.locations = {}
	for location, locationData in pairs(sbq.voreConfig.locations) do
		Locations.addLocation(location, locationData)
	end
	-- load states
	for name, stateConfig in pairs(sbq.voreConfig.states or {}) do
		States.addState(name, stateConfig)
	end
	if not States[storage.lastVoreState] then
		local defaultState = sbq.voreConfig.defaultState or "default"
		Transformation.state = States[defaultState]
		Transformation.stateName = defaultState
	else
		Transformation.state = States[storage.lastVoreState]
		Transformation.stateName = storage.lastState
	end
	-- put settings meant to be public and accessible by other entities in a status property
	for k, v in pairs(sbq.config.publicSettings) do
		if v then sbq.publicSettings[k] = sbq.settings[k] end
	end
	status.setStatusProperty("sbqPublicSettings", sbq.publicSettings)

	Transformation:init()
	Transformation.state:init()
	Transformation.active = true
end

function sbq.tryAction(...)
	Transformation:tryAction(...)
end

function sbq.getSettingsPageData()
    local settingsPageData = {
        storageSettings = storage.sbqSettings,
        settings = sbq.settings,
        voreConfig = sbq.voreConfig,
		locations = Locations.locations
    }
	return settingsPageData
end

function sbq.setSetting(k, v)
	storage.sbqSettings[k] = v
	if sbq.config.publicSettings[k] then
		sbq.publicSettings[k] = sbq.settings[k]
		status.setStatusProperty("sbqPublicSettings", sbq.publicSettings)
	end
end

function sbq.setLocationSetting(name, k, v)
    local location = Transformation:getLocation(name)
    storage.sbqSettings.locations[name][k] = v
	if location and location.settings[k] ~= v then
		location.occupancy.settingsDirty = true
	end
	if sbq.config.publicSettings[k] then
		sbq.publicSettings.locations[name][k] = sbq.settings.locations[name][k]
		status.setStatusProperty("sbqPublicSettings", sbq.publicSettings)
	end
end

function sbq.tryVore(target, locationName, throughput)
	local targetSize = math.sqrt(world.entityArea(target))
	if (targetSize <= ((throughput or 1) * sbq.scale)) then
		local location = Transformation:getLocation(locationName)
		local space, subLocation = location:hasSpace(targetSize)
		if space then
			Occupants.addOccupant(target, locationName, subLocation)
			return true
		end
	end
end

function sbq.tryLetout(target, throughput)
	local lounging = world.entityLoungingIn(entity.id())
	if lounging and not lounging.dismountable then return false end
	local occupant = Occupants.entityId[tostring(target)]
	if not occupant then return false end
	if not ((occupant.size * occupant.sizeMultiplier) <= ((throughput or 1) * sbq.scale)) then return false end
	return true, function ()
		occupant:remove()
	end
end


-- transformation handling
function _Transformation:getLocation(...)
	return self.state:getLocation(...)
end

function _Transformation:tryAction(...)
	return self.state:tryAction(...)
end

function _Transformation:changeState(stateName)
	local state = States[stateName]
	if not state then sbq.logError("Attempt to switch to invalid state: " .. stateName) return false end
	if self.lockStateChanges then return false end
	if stateName == self.stateName then return false end
	storage.lastVoreState = stateName
	self.state:uninit()
	self.stateName = stateName
	self.state = state
	self.state:init()
	return true
end

-- State Handling
function States.addState(stateName, config)
	local state = sb.jsonMerge(config, {})
	state.locations = state.locations or {}
	for k, location in pairs(state.locations) do
		setmetatable(location, {__index = Locations.locations[k]})
	end
	setmetatable(state.locations, {__index = Locations.locations})
	setmetatable(state, {__index = Transformation.states[stateName]})
	for actionName, action in pairs(state.actions or {}) do
		setmetatable(action, _Action)
	end
	States[stateName] = state
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
	sb.logInfo("attempting action")
	if not action then return false end
	if action.onCooldown then return false end
	if action.settings and not sbq.tableMatches(action.settings, sbq.settings) then sb.logInfo("fail settings") return self:actionFailed(name, action, target, ...) end
	if action.targetSettings then
		if not target or not world.entityExists(target) then sb.logInfo("no target") return self:actionFailed(name, action, target, ...) end
        local targetSettings = world.getStatusProperty(target, "sbqPublicSettings")
		sb.logInfo(sb.printJson(targetSettings or {},1))
		if not sbq.tableMatches(action.targetSettings, targetSettings) then return self:actionFailed(name, action, target, ...) end
	end
	local scriptResult, endFunction = true, false
	if action.script then scriptResult, endFunction = self.scripts[action.script](name, action, target, ...) end
	if not scriptResult then return self:actionFailed(name, action, target, ...) end
	local longest = self:doAnimations(action.animations, target)
	local cooldown = action.cooldown or longest
	action.onCooldown = true
	sbq.timer(name.."Cooldown", cooldown, function (...)
		action.onCooldown = false
		if type(endFunction) == "function" then
            endFunction(...)
        elseif type(endFunction) == "string" then
			self.scripts[endFunction](...)
		end
	end, name, action, target, ...)
	return scriptResult
end

function _State:actionFailed(name, action, target, ...)
	local cooldown = action.failureCooldown or 0
	action.onCooldown = true
	sbq.timer(name.."Cooldown", cooldown, function ()
		action.onCooldown = false
	end)
	return false
end

function _State:doAnimations(animations, target)
	local longest = 0
    local targetTags = {
        occupant = "occupant",
        right = sbq.facingRight and "front" or "back",
		left = sbq.facingRight and "back" or "front"
	}
	if target then
		local occupant = Occupants[tostring(target)]
		if occupant then
			targetTags.occupant = occupant.seat
		end
	end
	for k, v in pairs(animations or {}) do
		local state = sb.replaceTags(k, targetTags)
		if type(v) == "table" then
			animator.setAnimationState(state, v[1], v[2])
			animator.setAnimationReversed(state, v[3])
		else
			animator.setAnimationState(state, v)
			animator.setAnimationReversed(state, false)
		end
		local timer = animator.animationTimer(state)
		longest = math.max(longest, timer[2])
	end
	return longest
end

-- Location handling
function Locations.addLocation(name, config)
	local location = sb.jsonMerge(sbq.config.defaultLocationData, sbq.config.locations[name] or {}, sbq.getConfigArray(config))
	-- if infusion is enabled and someone is in the slot then modify the properties of that location accordingly
	if location.infusionSlot and sbq.settings[location.infusionType .. "Pred"] and sbq.settings[location.infusionSlot] then
		local infused = sbq.settings[location.infusionSlot]
		local species = infused.parameters.npcArgs.npcSpecies
		local voreConfig = sbq.getConfigArray(infused.parameters.voreConfig or root.speciesConfig(species).voreConfig or "/humanoid/any/vore.config")
		location = sb.jsonMerge(sbq.config.locations[name],
			{ species = voreConfig.tfSpecies or species },
			sbq.getConfigArray(
				sb.jsonQuery(voreConfig, "infusedLocations." .. species .. "." .. name) or
				sb.jsonQuery(voreConfig, "infusedLocations." .. name) or {}
			)
		)
        -- certain NPCs may not like performing certain actions, therefore they can disable them when infused
		local metatable = getmetatable(sbq.settings)
        sbq.settings = sb.jsonMerge(sbq.settings, sbq.getConfigArray(infused.parameters.overrideSettings or {}),
            sbq.getConfigArray(sb.jsonQuery(infused.parameters, "conditionalOverrideSettings." .. species .. "." .. name)
                or sb.jsonQuery(infused.parameters, "conditionalOverrideSettings." .. name) or {}))
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
		visualSize = 0,
		interpolating = false,
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
			visualSize = 0,
			interpolating = false,
			interpolateFrom = 0,
			interpolateTime = 0,
        }
		if k == "<left>" or k == "<right>" then
            subLocation.occupancy.sided = true
			subLocation.occupancy.lastDirection = sbq.facingRight
		end
		location.occupancy.subLocations[k] = subLocation.occupancy
		setmetatable(subLocation, {__index = location})
	end

	Occupants.locations[name] = location.occupancy
	location.settings = sbq.settings.locations[name]
	setmetatable(location, _Location)
	Locations.locations[name] = location
end

function _Location:hasSpace(size, subLocation)
	if self.maxCount and (#self.occupancy.list >= self.maxCount) then return false end
    if self.settings.hammerspace then return math.huge end
	if not self.subLocations then
		return self:getRemainingSpace(self.maxFill, self.occupancy.size, size)
    elseif subLocation then
		if self.subLocations[subLocation].maxCount and (#self.occupancy.subLocations[subLocation].list >= self.subLocations[subLocation].maxCount) then return false end
		-- if we got an input for a sublocation, check that specific one and return
		return self:getRemainingSpace(self.subLocations[subLocation].maxFill, self.occupancy.subLocations[subLocation].size), subLocation
    elseif self.subLocations[1] then
		if self.subLocations[1].maxCount and (#self.occupancy.subLocations[1].list >= self.subLocations[1].maxCount) then return false end
		-- if an array, assuming locations are ordered, only check if theres space in the first
		return self:getRemainingSpace(self.subLocations[1].maxFill, self.occupancy.subLocations[1].size), 1
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

function _Location:updateOccupancy(locationTag, subLocationBehavior)
	local directionTags = {
		right = sbq.facingRight and "front" or "back",
		left = sbq.facingRight and "back" or "front"
	}
	local prevVisualSize = self.occupancy.visualSize
	if self.occupancy.sizeDirty or self.occupancy.settingsDirty or (Occupants.lastScale ~= sbq.scale) then
		self.occupancy.size = (self.settings.visualSizeAdd and self.settings.visualSize) or 0
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
				self.occupancy.size = self.occupancy.size + (occupant.size * occupant.sizeMultiplier / sbq.scale)
			end
			self.occupancy.size = math.max(self.settings.visualSize, self.occupancy.size)
			self.occupancy.visualSize = sbq.getClosestValue(self.occupancy.size, self.struggleSizes or {0})
		end
        if prevVisualSize ~= self.occupancy.visualSize then

			self.occupancy.interpolating = true
			self.occupancy.interpolateFrom = prevVisualSize
			animator.setGlobalTag(sb.replaceTags(locationTag, directionTags), self.occupancy.visualSize)
		end
    end
	if self.occupancy.sided and (self.occupancy.lastDirection ~= sbq.facingRight) then
		animator.setGlobalTag(sb.replaceTags(locationTag, directionTags), self.occupancy.visualSize)
	end
	if self.occupancy.interpolating then
		-- TODO get the animation and do stuff with it here
	end
end

-- Occupant Handling
function Occupants.addOccupant(entityId, location, size, subLocation)
	local seat
	-- check for unoccupied occupant seat
	for i = 0, sbq.config.seatCount - 1 do
		if not loungeable.entityLoungingIn("occupant"..i) then
			seat = "occupant"..i
			break
		end
	end
	-- if there is no available seat we cannot add the occupant
	if not seat then return false end
	-- setup occupant values
	local occupant = {
		entityId = entityId,
		seat = seat,
		flags = {},
		location = location or "belly",
		subLocation = subLocation,
		size = size or 1,
		sizeMultiplier = 1,
		struggleGracePeriod = 0,
		struggleTime = 0,
		struggleCount = 0,
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
	occupant:refreshLocation()
	occupant:setLoungeEnabled(true)
	occupant:setDismountable(false)
	world.sendEntityMessage(entityId, "sbqForceSit", { index = occupant:getLoungeIndex(), source = entity.id() })
	return true
end

function _Occupant:remove()
	self:setLoungeEnabled(false)
	Occupants.locations[self.location].sizeDirty = true

	Occupants.seat[self.seat] = nil
	for k, occupant in pairs(Occupants.entityId) do
		if occupant.entityId == self.entityId then
			Occupants.entityId[k] = nil
			break
		end
	end
	for i, occupant in ipairs(Occupants.locations[self.location].list) do
		if occupant.entityId == self.entityId then
			table.remove(Occupants.locations[self.location].list, i)
			break
		end
	end
	for i, occupant in ipairs(Occupants.list) do
		if occupant.entityId == self.entityId then
			table.remove(Occupants.list, i)
			return
		end
	end
end

function Occupants.update(dt)
	for _, occupant in ipairs(Occupants.list) do
		occupant:update(dt)
	end
	for name, _ in pairs(Locations.locations) do
		local location = Transformation:getLocation(name)
		for k, v in pairs(location.subLocations or {}) do
			local subLocation = Transformation:getLocation(name, k)
			location.occupancy.sizeDirty = subLocation.occupancy.sizeDirty or location.occupancy.sizeDirty
			location.occupancy.settingsDirty = subLocation.occupancy.settingsDirty or location.occupancy.settingsDirty
			subLocation.occupancy.settingsDirty = subLocation.occupancy.settingsDirty or location.occupancy.settingsDirty
			subLocation:updateOccupancy(name.."_"..k)
		end
		location:updateOccupancy(name, location.subLocationBehavior)

		for k, _ in pairs(location.subLocations or {}) do
			local subLocation = Transformation:getLocation(name, k)
			subLocation.occupancy.sizeDirty = false
			subLocation.occupancy.settingsDirty = false
		end
		location.occupancy.settingsDirty = false
		location.occupancy.sizeDirty = false
		Occupants.lastScale = sbq.scale
	end
end

function _Occupant:update(dt)
    if not world.entityExists(self.entityId) then self:remove() end
	local location = Transformation:getLocation(self.location)
	if location.occupancy.settingsDirty then self:refreshLocation() end
	local locationStore = self.locationStore[self.location]

	locationStore.time = locationStore.time + dt

	if self.progressBar then
		self.progressBar.progress = self.progressBar.progress + (dt * self.progressBar.args.speed)
		if self.progressBar.progress >= 100 then self.progressBar.callback(self, self.progressBar.args) end
	end

	if not self.flags.digested then
		local oldMultiplier = self.sizeMultiplier
		local compression = location.settings.compression or sbq.settings.compression
		local compressionMin = location.settings.compressionMin or sbq.settings.compressionMin
		if compression == "time" then
			self.sizeMultiplier = math.max( compressionMin, self.sizeMultiplier - (status.stat("sbqDigestPower") * dt * sbq.config.compressionRate))
		elseif compression == "health" then
			local health = world.entityHealth(self.entityId)
			self.sizeMultiplier = math.max( compressionMin, (health[1] / health[2]))
		end
		if oldMultiplier ~= self.sizeMultiplier then
			Occupants.locations[self.location].sizeDirty = true
		end
	end
	self:checkStruggles(dt)
end

function _Occupant:setLoungeEnabled(...)
	return loungeable.setLoungeEnabled(self.seat, ...)
end
function _Occupant:setDismountable(...)
	return loungeable.setDismountable(self.seat, ...)
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
function _Occupant:setToolUsageSuppressed(...)
	return loungeable.setToolUsageSuppressed(self.seat, ...)
end
function _Occupant:controlHeld(...)
	return loungeable.controlHeld(self.seat, ...)
end
function _Occupant:controlHeldTime(...)
	return loungeable.controlHeldTime(self.seat, ...)
end
function _Occupant:setLoungeStatusEffects(...)
	return loungeable.setLoungeStatusEffects(self.seat, ...)
end
function _Occupant:getLoungeIndex()
	return loungeable.getIndexFromName(self.seat)
end

function _Occupant:controlPressed(control, time)
end
function _Occupant:controlReleased(control, time)
end

function _Occupant:refreshLocation(name, subLocation)
	local location = Transformation:getLocation(self.location, self.subLocation)

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
		location = Transformation:getLocation(self.location, self.subLocation)

		table.insert(location.occupancy.list, self)
		location.occupancy.sizeDirty = true
	end
	if not self.locationStore[self.location] then
		self.locationStore[self.location] = {
			time = 0,
			struggleTime = 0
		}
	end

	local persistentStatusEffects = {
		{ stat = "sbqDigestResistance", effectiveMultiplier = (1 / math.max(status.stat("sbqDigestPower"),0.01)) },
		{ stat = "sbqGetDigestDrops", amount = (1 and (location.settings.getDigestDrops or sbq.settings.getDigestDrops or false)) or 0}
	}
	util.appendLists(persistentStatusEffects, location.passiveEffects or {})
	util.appendLists(persistentStatusEffects, (location.mainEffect or {})[location.settings.mainEffect or sbq.settings.mainEffect or "none"] or {})
	for setting, effects in pairs(location.toggleEffects or {}) do
		if (location.settings[setting] or (sbq.settings[setting] and (location.settings[setting] == nil))) then
			util.appendLists(persistentStatusEffects, effects or {})
		end
	end
	self:setLoungeStatusEffects(persistentStatusEffects)

	self:setItemBlacklist(location.itemBlacklist or sbq.voreConfig.prey.itemBlacklist or sbq.config.prey.itemBlacklist)
	self:setItemWhitelist(location.itemWhitelist or sbq.voreConfig.prey.itemWhitelist or sbq.config.prey.itemWhitelist)
	self:setItemTagBlacklist(location.itemTagBlacklist or sbq.voreConfig.prey.itemTagBlacklist or sbq.config.prey.itemTagBlacklist)
	self:setItemTagWhitelist(location.itemTagWhitelist or sbq.voreConfig.prey.itemTagWhitelist or sbq.config.prey.itemTagWhitelist)
	self:setItemTypeBlacklist(location.itemTypeBlacklist or sbq.voreConfig.prey.itemTypeBlacklist or sbq.config.prey.itemTypeBlacklist)
	self:setItemTypeWhitelist(location.itemTypeWhitelist or sbq.voreConfig.prey.itemTypeWhitelist or sbq.config.prey.itemTypeWhitelist)
	self:setToolUsageSuppressed(location.toolUsageSuppressed or sbq.voreConfig.prey.toolUsageSuppressed or sbq.config.prey.toolUsageSuppressed)
end

function _Occupant:checkStruggles(dt)
	local location = Occupants.locations[self.location]
	local dx = 0
	local dy = 0
	local effectiveness = 1
	local staleTime = 5
	if self:controlHeld("Up") then
		dy = dy + 1
		if self:controlHeldTime("Up") > staleTime then effectiveness = effectiveness * 0.5 end
	end
	if self:controlHeld("Down") then
		dy = dy - 1
		if self:controlHeldTime("Down") > staleTime then effectiveness = effectiveness * 0.5 end
	end
	if self:controlHeld("Left") then
		dx = dx - (1 * sbq.facingDirection)
		if self:controlHeldTime("Left") > staleTime then effectiveness = effectiveness * 0.5 end
	end
	if self:controlHeld("Right") then
		dx = dx + (1 * sbq.facingDirection)
		if self:controlHeldTime("Right") > staleTime then effectiveness = effectiveness * 0.5 end
	end
	if dx ~= 0 or dy ~= 0 then
		self.struggleTime = self.struggleTime + (dt * effectiveness)
		self.locationStore[self.location].struggleTime = self.locationStore[self.location].struggleTime + dt
		self.struggleGracePeriod = self.sizeMultiplier * effectiveness -- might change this, but it's so struggles get more "difficult" the more compressed you are
		location.dx = location.dx + (dx * effectiveness)
		location.dy = location.dy + (dy * effectiveness)
	else
		if self.struggleGracePeriod <= 0 then
			self.struggleTime = self.struggleTime - dt
		else
			self.struggleGracePeriod = self.struggleGracePeriod - dt
		end
	end
end

function _Occupant:setProgressBar(name, args, callback, progress)
	self.progressBar.progress = progress or 0
	self.progressBar.args = args
	self.progressBar.name = name
	self.progressBar.callback = callback
end
