-- dummies to override with entity specific ones
function sbq.area()
	return 1
end
function sbq.facingDirection()
	return 1
end
function sbq.scale()
	return 1
end

function sbq.entityId()
	return entity.id()
end

function sbq.targetPosition()
	return entity.position()
end

function sbq.species()
	return sbq.voreConfig.entitySpecies or sbq.voreConfig.species or "sbq_dummy"
end

function sbq.directory()
	return "/humanoid/any/"
end

function sbq.say(line, tags, config)
end

function sbq.sayPortrait(line, portrait, tags, config)
end

function sbq.parentEntity()
end
function sbq.getItemSlot(slot)
end

function sbq.sayDialogue(string, tags, imagePortrait, emote, appendName)
	if type(string) == "string" and string ~= "" then
		if string:find("<love>") then
			status.addEphemeralEffect("love")
		end
		if string:find("<slowlove>") then
			status.addEphemeralEffect("slowlove")
		end
		if string:find("<confused>") then
			status.addEphemeralEffect("sbqConfused")
		end
		if string:find("<sleepy>") then
			status.addEphemeralEffect("sbqSleepy")
		end
		if string:find("<sad>") then
			status.addEphemeralEffect("sbqSad")
		end
		if string:find("<dontSpeak>") then return end

		string = sb.replaceTags(string, tags)
		if string == "" then return end

		if appendName then
			string = world.entityName(entity.id())..":\n"..string
		end
		if type(imagePortrait) == "string" then
			sbq.sayPortrait(string, imagePortrait, nil, {})
		else
			sbq.say(string, nil, {})
		end
		if type(emote) == "string" then
			sbq.emote(emote)
		end
	end
end


function sbq.setLoungeControlHeld(control)
end
function sbq.releaseLoungeControl(control)
end
function sbq.isLoungeControlHeld(control)
end

function sbq.loungingIn()
end

function sbq.setProperty(name, value)
end

function sbq.stat(name)
	return storage.stats[name] or 0
end
function sbq.statPositive(name)
	return sbq.stat(name) > 0
end

function sbq.isResource(name)
	return storage.resources[name] ~= nil
end
function sbq.resource(name)
	return storage.resources[name]
end
function sbq.resourcePositive(name)
	return storage.resources[name] > 0
end
function sbq.setResource(name, value)
	storage.resources[name] = math.max(0, math.min(value, sbq.resourceMax(name)))
end
function sbq.modifyResource(name, value)
	storage.resources[name] = math.max(0, math.min(storage.resources[name] + value, sbq.resourceMax(name)))
end
function sbq.giveResource(name, value)
	if not sbq.isResource(name) then return 0 end
	local oldVal = sbq.resource(name)
	sbq.modifyResource(name, value)
	return sbq.resource(name) - oldVal
end
function sbq.consumeResource(name, value)
	if not sbq.isResource(name) then return false end
	if value < 0 then return false end
	if sbq.resourceLocked(name) then return false end
	if sbq.resource(name) >= value then
		sbq.modifyResource(name, -value)
		sbq.notifyResourceConsumed(name, value)
		return true
	end
end
function sbq.overConsumeResource(name, value)
	if not sbq.isResource(name) then return false end
	if value < 0 then return false end
	if sbq.resourceLocked(name) then return false end
	sbq.modifyResource(name, -value)
	sbq.notifyResourceConsumed(name, value)
	return true
end
function sbq.resourceLocked(name)
	return storage.resourcesLocked[name] or false
end
function sbq.setResourceLocked(name,locked)
	storage.resourcesLocked[name] = locked
end
function sbq.resetResource(name)
	storage.resources[name] = storage.resourceData[name].initialValue or (storage.resourceData[name].initalPercentage and (storage.resourceData[name].initalPercentage * sbq.resourceMax(name))) or 0
end
function sbq.resetAllResources()
	for name, data in pairs(storage.resourceData) do
		sbq.resetResource(name)
	end
end
function sbq.resourceMax(name)
	return (storage.resourceData[name].maxValue or (storage.resourceData[name].maxStat and sbq.stat(storage.resourceData[name].maxStat))) or math.huge
end
function sbq.resourcePercentage(name)
	if sbq.resourceMax(name) == math.huge then sb.logError(("resourcePercentage called on resource '%s' which has no maximum").format(name)) return 0 end
	return storage.resources[name] / sbq.resourceMax(name)
end
function sbq.setResourcePercentage(name, value)
	if sbq.resourceMax(name) == math.huge then sb.logError(("setResourcePercentage called on resource '%s' which has no maximum").format(name)) return end
	storage.resources[name] = sbq.resourceMax(name) * value
end
function sbq.modifyResourcePercentage(name, value)
	if sbq.resourceMax(name) == math.huge then sb.logError(("modifyResourcePercentage called on resource '%s' which has no maximum").format(name)) return end
	sbq.modifyResource(name, value * sbq.resourceMax(name))
end

function sbq.initStats(config)
	local output = {}
	for k, v in pairs(config) do
		output[k] = v.baseValue
	end
	return output
end

function sbq.setStatModifiers(category, modifiers)
	storage.effectCategories[category] = modifiers
	sbq.calculateStats()
end

function sbq.clearStatModifiers(category)
	storage.effectCategories[category] = nil
end

function sbq.calculateStats()
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
function sbq.getDefaultResources()
	local resources = {}
	for name, data in pairs(storage.resourceData) do
		resources[name] = data.initialValue or (data.initalPercentage and (data.initalPercentage * sbq.resourceMax(name))) or 0
	end
	return resources
end
function sbq.resourceDeltas(dt)
	for name, data in pairs(storage.resourceData) do
		if data.deltaValue then
			storage.resources[name] = storage.resources[name] + data.deltaValue * dt
		elseif data.deltaStat then
			storage.resources[name] = storage.resources[name] + sbq.stat(data.deltaStat) * dt
		end
	end
end

function sbq.notifyResourceConsumed(resource, amount)
	if resource == "energy" and amount > 0 then
		sbq.setResourcePercentage("energyRegenBlock", 1.0)
	end
end
