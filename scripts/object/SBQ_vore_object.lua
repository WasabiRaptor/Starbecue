sbq = {}
require"/scripts/any/SBQ_RPC_handling.lua"
require"/scripts/any/SBQ_override_dummies.lua"
require"/scripts/any/SBQ_status.lua"
require"/scripts/any/SBQ_vore_main.lua"
require"/scripts/any/SBQ_rewards.lua"
require"/scripts/any/SBQ_dialogue.lua"
require"/scripts/any/SBQ_dialogue_scripts.lua"

function init()
	for k, v in pairs(config.getParameter("scriptStorage") or {}) do
		if storage[k] == nil then storage[k] = v end
	end
	sbq.config = root.assetJson("/sbq.config")
	sbq.pronouns = root.assetJson("/sbqPronouns.config")

	sbq.facingDirection = object.direction

	sbq.entityId = entity.id

	sbq.say = object.say
	sbq.sayPortrait = object.sayPortrait

	status.setStatusProperty = object.setConfigParameter

	sbq.dialogueTree = sbq.fetchConfigArray(config.getParameter("dialogueTree"))

	storage.baseStats = sbq.initStats(config.getParameter("stats") or {})
	storage.effectCategories = sb.jsonMerge(config.getParameter("effectCategories") or {}, storage.effectCategories or {})
	storage.stats = storage.stats or {}
	status.calculateStats()
	storage.resourceData = config.getParameter("resources") or {}
	storage.resources = sb.jsonMerge(status.getDefaultResources(), storage.resources or {})
	storage.resourcesLocked = storage.resourcesLocked or {}

	storage.sbqSettings = storage.sbqSettings or config.getParameter("sbqSettings") or {}
	storage.sbqUpgrades = storage.sbqUpgrades or config.getParameter("sbqUpgrades") or {}
	if not storage.sbqUpgrades.candiesEaten then
		storage.sbqUpgrades.candiesEaten = {}
		for i = 1, math.floor(math.max(object.level(), 1)) do
			storage.sbqUpgrades.candiesEaten[i] = 1
		end
		local digestPower = math.max(1, (object.level()+1)/2)
		storage.sbqSettings.acidDigestPower = storage.sbqSettings.acidDigestPower or digestPower
		storage.sbqSettings.cumDigestPower = storage.sbqSettings.cumDigestPower or digestPower
		storage.sbqSettings.femcumDigestPower = storage.sbqSettings.femcumDigestPower or digestPower
		storage.sbqSettings.milkDigestPower = storage.sbqSettings.milkDigestPower or digestPower
		storage.sbqSettings.escapeDifficulty = storage.sbqSettings.escapeDifficulty or digestPower
	end

	sbq.init(config.getParameter("voreConfig"))
end

function update(dt)
	sbq.checkRPCsFinished(dt)
	sbq.checkTimers(dt)
	status.update(dt)

	if status.resource("energy") == 0 then
		status.setResourceLocked("energy", true)
	elseif status.resourcePercentage("energy") == 1 then
		status.setResourceLocked("energy", false)
	end

	if not status.resourcePositive("energyRegenBlock") then
		status.modifyResourcePercentage("energy", status.stat("energyRegenPercentageRate") * dt)
	end

	sbq.update(dt)
end

function uninit()
	sbq.uninit()
end

function die()
	for i, occupant in ipairs(Occupants.list) do
		occupant:remove()
	end
end

function onInteraction(args)
	return SpeciesScript:interact(args)
end

function sbq.area()
	return #object.spaces()
end
