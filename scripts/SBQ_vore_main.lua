require "/scripts/util.lua"
require "/scripts/SBQ_util.lua"

_State = {}
_State.__index = _State

_Action = {}
_Action.__index = _Action

_Location = {}
_Location.__index = _Location

_Occupant = {}
_Occupant.__index = _Occupant

States = {}

Locations = {}

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
	sbq.reloadVoreConfig(storage.lastVoreConfig)
end

function sbq.update(dt)
	Occupants.update(dt)
end

function sbq.reloadVoreConfig(config)
	-- reset setting tables on reload
	sbq.publicSettings = { locations = {} }
    sbq.overrideSettings = { locations = {} }
	sbq.settings = sb.jsonMerge(sbq.config.defaultSettings, storage.settings or { locations = {} })

	-- store the last input so it's used again on the next initiaization
    storage.lastVoreConfig = config

	-- load config from species or config input, such as from a tech transformation
    sbq.voreConfig = sbq.getConfigArray(config or root.speciesConfig(humanoid.species()).voreConfig or "/humanoid/any/vore.config")
	-- load scripts
	for _, script in (sbq.voreConfig.scripts or {}) do
		require(script)
    end
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
		Locations.addLocation(location, locationData)
    end
	-- load states
	for name, stateConfig in (sbq.voreConfig.states or {}) do
		States.addState(name, stateConfig)
	end
	-- override settings with the override settings
    sbq.settings = sb.jsonMerge(sbq.settings or {}, sbq.overrideSettings or {})
	-- put settings meant to be public and accessible by other entities in a status property
    for k, v in pairs(sbq.config.publicSettings) do
		if v then sbq.publicSettings[k] = sbq.settings[k] end
    end
	status.setStatusProperty("sbqPublicSettings", sbq.publicSettings)
end

function sbq.setSetting(k,v)
    storage.settings[k] = v
    sbq.settings[k] = sbq.overrideSettings[k] or v
	if sbq.config.publicSettings[k] then
        sbq.publicSettings[k] = sbq.settings[k]
		status.setStatusProperty("sbqPublicSettings", sbq.publicSettings)
	end
end

function sbq.setLocationSetting(location,k,v)
    storage.settings.locations[location][k] = v
    sbq.settings.locations[location][k] = sbq.overrideSettings.locations[location][k] or v
	if sbq.config.publicSettings[k] then
        sbq.publicSettings.locations[location][k] = sbq.settings.locations[location][k]
		status.setStatusProperty("sbqPublicSettings", sbq.publicSettings)
	end
end

-- State Handling
function States.addState(name, config)
    local state = sb.jsonMerge(config, {})
	setmetatable(state, _State)
	for actionName, action in pairs(state.actions or {}) do
		setmetatable(action, _Action)
	end
end

-- Location handling

function Locations.addLocation(name, config)
	storage.settings.locations[name] = storage.settings.locations[name] or {}
    sbq.overrideSettings.locations[name] = sbq.overrideSettings.locations[name] or {}
    sbq.publicSettings.locations[name] = sbq.publicSettings.locations[name] or {}
    sbq.settings.locations[name] = sbq.settings.locations[name] or {}

	local location = sb.jsonMerge(sbq.config.defaultLocationData[name], sbq.getConfigArray(config))
	-- if infusion is enabled and someone is in the slot then modify the properties of that location accordingly
	if location.infusionSlot and sbq.settings[location.infusionType .. "Pred"] and sbq.settings[location.infusionSlot] then
		local infused = sbq.settings[location.infusionSlot]
		local species = infused.parameters.npcArgs.npcSpecies
		local voreConfig = sbq.getConfigArray(infused.parameters.voreConfig or root.speciesConfig(species).voreConfig or "/humanoid/any/vore.config")
        location = sb.jsonMerge(sbq.config.defaultLocationData[name],
            { species = voreConfig.tfSpecies or species },
            sbq.getConfigArray(
				sb.jsonQuery(voreConfig, "infusedLocations." .. species .. "." .. name) or
                sb.jsonQuery(voreConfig, "infusedLocations." .. name) or {}
			)
		)
		-- certain NPCs may not like performing certain actions, therefore they can disable them when infused
		sbq.overrideSettings = sb.jsonMerge(sbq.overrideSettings,  sbq.getConfigArray(infused.parameters.overrideSettings or {}), sbq.getConfigArray(sb.jsonQuery(infused.parameters, "conditionalOverrideSettings." .. species .. "." .. name) or sb.jsonQuery(infused.parameters, "conditionalOverrideSettings."..name) or {}))
	end
	-- setup the default settings for that location
	sbq.settings.locations[name] = sb.jsonMerge(sbq.config.defaultLocationSettings, config.defaultSettings or {}, sbq.settings.locations[name] or {})
	-- setup occupancy values
	Occupants.locations[name] = {
		sizeDirty = true,
		settingsDirty = true,
		list = {},
		size = 0,
		visualSize = 0,
		interpolating = false,
		interpolateFrom = 0,
		interpolateTime = 0,
    }
	setmetatable(location, _Location)
	Locations[name] = location
end


-- Occupant Handling
function Occupants.addOccupant(entityId, location, size)
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
    for location, data in pairs(Occupants.locations) do
        if data.sizeDirty or (Occupants.lastScale ~= mcontroller.scale()) then
			local prevVisualSize = data.visualSize
			data.size = (sbq.settings[location].visualSizeAdd and sbq.settings[location].visualSize) or 0
			for _, occupant in ipairs(data.list) do
				data.size = data.size + (occupant.size * occupant.sizeMultiplier / mcontroller.scale())
            end
            data.size = math.max(sbq.settings[location].visualSize, data.size)
            data.visualSize = sbq.getClosestValue(data.size, Locations[location].struggleSizes)
            if prevVisualSize ~= data.visualSize then
                data.interpolating = true
                data.interpolateFrom = prevVisualSize
				animator.setGlobalTag(location.."Occupants", data.visualSize)
			end
        end
		if data.interpolating then

		end
        data.settingsDirty = false
        data.sizeDirty = false
		Occupants.lastScale = mcontroller.scale()
	end
end

function _Occupant:update(dt)
    if not world.entityExists(self.entityId) then self:remove() end
    if Occupants.locations[self.location].settingsDirty then self:refreshLocation() end

	local locationSettings = (sbq.settings.locations or {})[self.location] or {}
    local locationStore = self.locationStore[self.location]

	locationStore.time = locationStore.time + dt

	if self.progressBar then
		self.progressBar.progress = self.progressBar.progress + (dt * self.progressBar.args.speed)
		if self.progressBar.progress >= 100 then self.progressBar.callback(self, self.progressBar.args) end
	end

    if not self.flags.digested then
		local oldMultiplier = self.sizeMultiplier
        local compression = locationSettings.compression or sbq.settings.compression
		local compressionMin = locationSettings.compressionMin or sbq.settings.compressionMin
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

function _Occupant:refreshLocation(location)
    if location and (self.location ~= location) then
		Occupants.locations[self.location].sizeDirty = true
		for i, occupant in ipairs(Occupants.locations[self.location].list) do
			if occupant.entityId == self.entityId then
                table.remove(Occupants.locations[self.location].list, i)
				break
			end
        end
        table.insert(Occupants.locations[location].list, self)
		Occupants.locations[location].sizeDirty = true
        self.location = location
	end
    local locationData = Locations[self.location] or {}
	local locationSettings = (sbq.settings.locations or {})[self.location] or {}
	if not self.locationStore[self.location] then
        self.locationStore[self.location] = {
            time = 0,
			struggleTime = 0
		}
    end

    local persistentStatusEffects = {
        { stat = "sbqDigestResistance", effectiveMultiplier = (1 / math.max(status.stat("sbqDigestPower"),0.01)) },
		{ stat = "sbqGetDigestDrops", amount = (1 and (locationSettings.getDigestDrops or sbq.settings.getDigestDrops or false)) or 0}
	}
	util.appendLists(persistentStatusEffects, locationData.passiveEffects or {})
	util.appendLists(persistentStatusEffects, (locationData.mainEffect or {})[locationSettings.mainEffect or sbq.settings.mainEffect or "none"] or {})
    for setting, effects in pairs(locationData.toggleEffects or {}) do
		if (locationSettings[setting] or (sbq.settings[setting] and (locationSettings[setting] == nil))) then
			util.appendLists(persistentStatusEffects, effects or {})
		end
	end
    self:setLoungeStatusEffects(persistentStatusEffects)

	self:setItemBlacklist(locationData.itemBlacklist or sbq.voreConfig.prey.itemBlacklist or sbq.config.prey.itemBlacklist)
	self:setItemWhitelist(locationData.itemWhitelist or sbq.voreConfig.prey.itemWhitelist or sbq.config.prey.itemWhitelist)
	self:setItemTagBlacklist(locationData.itemTagBlacklist or sbq.voreConfig.prey.itemTagBlacklist or sbq.config.prey.itemTagBlacklist)
	self:setItemTagWhitelist(locationData.itemTagWhitelist or sbq.voreConfig.prey.itemTagWhitelist or sbq.config.prey.itemTagWhitelist)
	self:setItemTypeBlacklist(locationData.itemTypeBlacklist or sbq.voreConfig.prey.itemTypeBlacklist or sbq.config.prey.itemTypeBlacklist)
	self:setItemTypeWhitelist(locationData.itemTypeWhitelist or sbq.voreConfig.prey.itemTypeWhitelist or sbq.config.prey.itemTypeWhitelist)
    self:setToolUsageSuppressed(locationData.toolUsageSuppressed or sbq.voreConfig.prey.toolUsageSuppressed or sbq.config.prey.toolUsageSuppressed)
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
        dx = dx - (1 * mcontroller.facingDirection())
		if self:controlHeldTime("Left") > staleTime then effectiveness = effectiveness * 0.5 end
	end
    if self:controlHeld("Right") then
        dx = dx + (1 * mcontroller.facingDirection())
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
