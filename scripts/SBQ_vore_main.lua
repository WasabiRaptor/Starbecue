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
end
function controlReleased(seat, control, time)
	if Occupants.seat[seat] then Occupants.seat[seat]:controlReleased(control, time) end
end

function sbq.update(dt)
	Occupants.update(dt)

end

function Occupants.addOccupant(entityId, location, size)
    local availableSeats = { true, true, true, true, true, true, true, true }
    local seat = 0
	for _, occupant in ipairs(Occupants.list) do
		availableSeats[occupant.seat + 1] = false
	end
	for k,v in ipairs(availableSeats) do
        if v then seat = k - 1 break end
		if k == #availableSeats then return false end
	end
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
    Occupants.seat[tostring(seat)] = occupant
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
	world.sendEntityMessage(entityId, "sbqForceSit", { index = seat, source = entity.id() })
	return true
end
function _Occupant:remove()
    self:setLoungeEnabled(false)
    Occupants.locations[self.location].sizeDirty = true

    Occupants.seat[tostring(self.seat)] = nil
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
			data.size = (storage.settings[location].visualSizeAdd and storage.settings[location].visualSize) or 0
			for _, occupant in ipairs(data.list) do
				data.size = data.size + (occupant.size * occupant.sizeMultiplier / mcontroller.scale())
            end
            data.size = math.max(storage.settings[location].visualSize, data.size)
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

	local locationSettings = storage.settings.locations[self.location] or {}
    local locationStore = self.locationStore[self.location]

	locationStore.time = locationStore.time + dt

	if self.progressBar then
		self.progressBar.progress = self.progressBar.progress + (dt * self.progressBar.args.speed)
		if self.progressBar.progress >= 100 then self.progressBar.callback(self, self.progressBar.args) end
	end

    if not self.flags.digested then
		local oldMultiplier = self.sizeMultiplier
        local compression = locationSettings.compression or storage.settings.compression
		local compressionMin = locationSettings.compressionMin or storage.settings.compressionMin
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
	loungeable.setLoungeEnabled(tostring(self.seat), ...)
end
function _Occupant:setDismountable(...)
	loungeable.setDismountable(tostring(self.seat), ...)
end
function _Occupant:setItemBlacklist(...)
	loungeable.setItemBlacklist(tostring(self.seat), ...)
end
function _Occupant:setItemWhitelist(...)
	loungeable.setItemWhitelist(tostring(self.seat), ...)
end
function _Occupant:setItemTagBlacklist(...)
	loungeable.setItemTagBlacklist(tostring(self.seat), ...)
end
function _Occupant:setItemTagWhitelist(...)
	loungeable.setItemTagWhitelist(tostring(self.seat), ...)
end
function _Occupant:setItemTypeBlacklist(...)
	loungeable.setItemTypeBlacklist(tostring(self.seat), ...)
end
function _Occupant:setItemTypeWhitelist(...)
	loungeable.setItemTypeWhitelist(tostring(self.seat), ...)
end
function _Occupant:setToolUsageSuppressed(...)
	loungeable.setToolUsageSuppressed(tostring(self.seat), ...)
end
function _Occupant:controlHeld(...)
	loungeable.controlHeld(tostring(self.seat), ...)
end
function _Occupant:controlTime(...)
	loungeable.controlTime(tostring(self.seat), ...)
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
    local locationData = Locations[self.location]
	local locationSettings = storage.settings.locations[self.location] or {}
	if not self.locationStore[self.location] then
        self.locationStore[self.location] = {
            time = 0,
			struggleTime = 0
		}
    end

    local persistentStatusEffects = {
        { stat = "sbqDigestResistance", effectiveMultiplier = (1 / status.stat("sbqDigestPower")) },
		{ stat = "sbqGetDigestDrops", amount = (locationSettings.getDigestDrops or storage.settings.getDigestDrops or false) and 1}
	}
	util.appendLists(persistentStatusEffects, locationData.passiveEffects)
	util.appendLists(persistentStatusEffects, locationData.mainEffect[locationSettings.mainEffect or storage.settings.mainEffect or "none"])
    for setting, effects in pairs(locationData.toggleEffects) do
		if (locationSettings[setting] or (storage.settings[setting] and (locationSettings[setting] == nil))) then
			util.appendLists(persistentStatusEffects, effects)
		end
	end
	loungeable.setLoungeStatusEffects("seat"..self.seat, persistentStatusEffects)

end

function _Occupant:checkStruggles(dt)
    local location = Occupants.locations[self.location]
    local dx = 0
	local dy = 0
    local effectiveness = 1
	local staleTime = 5
    if self:controlHeld("Up") then
        dy = dy + 1
        if self:controlTime("Up") > staleTime then effectiveness = effectiveness * 0.5 end
	end
    if self:controlHeld("Down") then
        dy = dy - 1
		if self:controlTime("Down") > staleTime then effectiveness = effectiveness * 0.5 end
	end
    if self:controlHeld("Left") then
        dx = dx - (1 * mcontroller.facingDirection())
		if self:controlTime("Left") > staleTime then effectiveness = effectiveness * 0.5 end
	end
    if self:controlHeld("Right") then
        dx = dx + (1 * mcontroller.facingDirection())
		if self:controlTime("Right") > staleTime then effectiveness = effectiveness * 0.5 end
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
