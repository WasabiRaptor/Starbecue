require "/scripts/util.lua"
require "/scripts/SBQ_math.lua"

Locations = {}

_Occupant = {}
_Occupant.__index = _Occupant

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
	sbq.settings = sb.jsonMerge(sbq.config.defaultSettings, storage.settings or {})
	message.setHandler("sbqAddOccupant", function (_,_, ...)
		Occupants.addOccupant(...)
	end)
end

function sbq.update(dt)
	Occupants.update(dt)
end

local seats = 15 -- 0 indexed

function Occupants.addOccupant(entityId, location, size)
    local seat
	for i = 0, seats do
		if not loungeable.entityLoungingIn("occupant"..i) then
            seat = "occupant"..i
			break
		end
    end
    if not seat then return false end
	local occupant = {
		entityId = entityId,
		seat = seat,
		flags = {},
        location = location or "belly",
		size = size or 1,
        sizeMultiplier = 1,
		struggleGracePeriod = 0,
		struggleTimer = 0,
		locationStore = {},
		progressBar = nil,
	}
	setmetatable(occupant, _Occupant)
    table.insert(Occupants.list, occupant)
    Occupants.seat[seat] = occupant
    Occupants.entityId[tostring(entityId)] = occupant
	local uuid = world.entityUniqueId(entityId)
	if uuid then
		Occupants.entityId[uuid] = occupant
	end
    occupant:refreshLocation()
    occupant:setLoungeEnabled(true)
	occupant:setDismountable(false)
	occupant:setItemBlacklist(sbq.config.prey.itemBlacklist)
	occupant:setItemWhitelist(sbq.config.prey.itemWhitelist)
	occupant:setItemTagBlacklist(sbq.config.prey.itemTagBlacklist)
	occupant:setItemTagWhitelist(sbq.config.prey.itemTagWhitelist)
	occupant:setItemTypeBlacklist(sbq.config.prey.itemTypeBlacklist)
	occupant:setItemTypeWhitelist(sbq.config.prey.itemTypeWhitelist)
    occupant:setToolUsageSuppressed(sbq.config.prey.toolUsageSuppressed)
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
			self.sizeMultiplier = math.max( compressionMin or 0.25, self.sizeMultiplier - (status.stat("sbqDigestPower") * dt * 0.01))
        elseif compression == "health" then
			local health = world.entityHealth(self.entityId)
			self.sizeMultiplier = math.max( compressionMin or 0.25, (health[1] / health[2]))
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
        self.struggleTimer = self.struggleTimer + (dt * effectiveness)
		self.locationStore[self.location].struggleTime = self.locationStore[self.location].struggleTime + dt
        self.struggleGracePeriod = self.sizeMultiplier * effectiveness -- might change this, but it's so struggles get more "difficult" the more compressed you are
        location.dx = location.dx + (dx * effectiveness)
		location.dy = location.dy + (dy * effectiveness)
    else
		if self.struggleGracePeriod <= 0 then
            self.struggleTimer = self.struggleTimer - dt
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
