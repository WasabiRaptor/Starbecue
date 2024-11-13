sbq = {}
require"/scripts/any/SBQ_RPC_handling.lua"
require"/scripts/any/SBQ_override_dummies.lua"
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

	sbq.setProperty = object.setConfigParameter

	sbq.dialogueTree = root.fetchConfigArray(config.getParameter("dialogueTree"))

	storage.baseStats = sbq.initStats(config.getParameter("stats") or {})
	storage.effectCategories = sb.jsonMerge(config.getParameter("effectCategories") or {}, storage.effectCategories or {})
	storage.stats = storage.stats or {}
	sbq.calculateStats()
	storage.resourceData = config.getParameter("resources") or {}
	storage.resources = sb.jsonMerge(sbq.getDefaultResources(), storage.resources or {})
	storage.resourcesLocked = storage.resourcesLocked or {}

	storage.sbqSettings = storage.sbqSettings or config.getParameter("sbqSettings") or {}
	storage.sbqUpgrades = storage.sbqUpgrades or config.getParameter("sbqUpgrades") or {}
	if not storage.sbqUpgrades.candiesEaten then
		storage.sbqUpgrades.candiesEaten = {}
		for i = 1, math.max(object.level(), 1) do
			storage.sbqUpgrades.candiesEaten[i] = 1
	end
		storage.sbqSettings.maxDigestPower = math.max(1, (object.level()+1)/2)
	end

	sbq.init(config.getParameter("voreConfig"))
end

function update(dt)
	sbq.checkRPCsFinished(dt)
	sbq.checkTimers(dt)
	sbq.resourceDeltas(dt)

	if sbq.resource("energy") == 0 then
		sbq.setResourceLocked("energy", true)
	elseif sbq.resourcePercentage("energy") == 1 then
		sbq.setResourceLocked("energy", false)
	end

	if not sbq.resourcePositive("energyRegenBlock") then
		sbq.modifyResourcePercentage("energy", sbq.stat("energyRegenPercentageRate") * dt)
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
