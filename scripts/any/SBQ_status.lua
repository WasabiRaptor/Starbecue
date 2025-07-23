status = {}
function status.setStatusProperty(name, value)
    sbq.debugLogWarn("Dummy function setStatusProperty was called to set: "..name.. " ".. sb.printJson(value))
end

function status.stat(name)
	return storage.stats[name] or 0
end
function status.statPositive(name)
	return status.stat(name) > 0
end

function status.isResource(name)
	return storage.resources[name] ~= nil
end
function status.resource(name)
	return storage.resources[name]
end
function status.resourcePositive(name)
	return storage.resources[name] > 0
end
function status.setResource(name, value)
	storage.resources[name] = math.max(0, math.min(value, status.resourceMax(name)))
end
function status.modifyResource(name, value)
	storage.resources[name] = math.max(0, math.min(storage.resources[name] + value, status.resourceMax(name)))
end
function status.giveResource(name, value)
	if not status.isResource(name) then return 0 end
	local oldVal = status.resource(name)
	status.modifyResource(name, value)
	return status.resource(name) - oldVal
end
function status.consumeResource(name, value)
	if not status.isResource(name) then return false end
	if value < 0 then return false end
	if status.resourceLocked(name) then return false end
	if status.resource(name) >= value then
		status.modifyResource(name, -value)
		status.notifyResourceConsumed(name, value)
		return true
	end
end
function status.overConsumeResource(name, value)
	if not status.isResource(name) then return false end
	if value < 0 then return false end
	if status.resourceLocked(name) then return false end
	status.modifyResource(name, -value)
	status.notifyResourceConsumed(name, value)
	return true
end
function status.resourceLocked(name)
	return storage.resourcesLocked[name] or false
end
function status.setResourceLocked(name,locked)
	storage.resourcesLocked[name] = locked
end
function status.resetResource(name)
	storage.resources[name] = storage.resourceData[name].initialValue or (storage.resourceData[name].initalPercentage and (storage.resourceData[name].initalPercentage * status.resourceMax(name))) or 0
end
function status.resetAllResources()
	for name, data in pairs(storage.resourceData) do
		status.resetResource(name)
	end
end
function status.resourceMax(name)
	return (storage.resourceData[name].maxValue or (storage.resourceData[name].maxStat and status.stat(storage.resourceData[name].maxStat))) or math.huge
end
function status.resourcePercentage(name)
	if status.resourceMax(name) == math.huge then sb.logError(("resourcePercentage called on resource '%s' which has no maximum").format(name)) return 0 end
	return storage.resources[name] / status.resourceMax(name)
end
function status.setResourcePercentage(name, value)
	if status.resourceMax(name) == math.huge then sb.logError(("setResourcePercentage called on resource '%s' which has no maximum").format(name)) return end
	storage.resources[name] = status.resourceMax(name) * value
end
function status.modifyResourcePercentage(name, value)
	if status.resourceMax(name) == math.huge then sb.logError(("modifyResourcePercentage called on resource '%s' which has no maximum").format(name)) return end
	status.modifyResource(name, value * status.resourceMax(name))
end

function sbq.initStats(config)
	local output = {}
	for k, v in pairs(config) do
		output[k] = v.baseValue
	end
	return output
end

function status.setPersistentEffects(category, modifiers)
	storage.effectCategories[category] = modifiers
	status.calculateStats()
end

function status.clearPersistentEffects(category)
	storage.effectCategories[category] = nil
end

function status.calculateStats()
	local stats = {}
	for _, modifiers in pairs(storage.effectCategories) do
		for _, modifier in ipairs(modifiers) do
			if modifier.stat then
				storage.baseStats[modifier.stat] = storage.baseStats[modifier.stat] or 0
				stats[modifier.stat] = stats[modifier.stat] or {baseModified = 0, effectiveMultiplier = 1}
				if modifier.baseMultiplier then
					stats[modifier.stat].baseModified = stats[modifier.stat].baseModified + (storage.baseStats[modifier.stat] * (modifier.baseMultiplier - 1))
				elseif modifier.amount then
					stats[modifier.stat].baseModified = stats[modifier.stat].baseModified + modifier.amount
				elseif modifier.effectiveMultiplier then
					stats[modifier.stat].effectiveMultiplier = stats[modifier.stat].effectiveMultiplier * modifier.effectiveMultiplier
				end
			end
		end
	end
	for stat, base in pairs(storage.baseStats) do
		local modifiers = stats[stat]
		if modifiers then
			storage.stats[stat] = (base + modifiers.baseModified) * modifiers.effectiveMultiplier
		else
			storage.stats[stat] = base
		end
	end
end
function status.getDefaultResources()
	local resources = {}
	for name, data in pairs(storage.resourceData) do
		resources[name] = data.initialValue or (data.initalPercentage and (data.initalPercentage * status.resourceMax(name))) or 0
	end
	return resources
end
function status.update(dt)
	for name, data in pairs(storage.resourceData) do
		if data.deltaValue then
			storage.resources[name] = storage.resources[name] + data.deltaValue * dt
		elseif data.deltaStat then
			storage.resources[name] = storage.resources[name] + status.stat(data.deltaStat) * dt
		end
	end
end

function status.notifyResourceConsumed(resource, amount)
	if resource == "energy" and amount > 0 then
		status.setResourcePercentage("energyRegenBlock", 1.0)
	end
end
