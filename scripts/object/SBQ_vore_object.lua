sbq = {}
require"/scripts/any/SBQ_RPC_handling.lua"
require"/scripts/any/SBQ_override_dummies.lua"
require"/scripts/any/SBQ_status.lua"
require"/scripts/any/SBQ_vore_main.lua"
require"/scripts/any/SBQ_rewards.lua"
require"/scripts/any/SBQ_dialogue.lua"
require"/scripts/any/SBQ_dialogue_scripts.lua"

function init()
	loungeable = object
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
	sbq.settings = sbq._Settings.new(
		sb.jsonMerge(
			config.getParameter("sbqSettingsConfig")
		),
		storage.sbqSettings or config.getParameter("sbqSettings"),
		entity.entityType()
	)
	sbq.settings:setParameterSettings()
	sbq.settings:setMessageHandlers()

	sbq.upgrades = sbq._Upgrades.new(storage.sbqUpgrades or config.getParameter("sbqUpgrades"))
	sbq.upgrades:setMessageHandlers()

	sbq.upgrades:apply(sbq.settings)
	if not sbq.upgrades.storedUpgrades.candyBonus then
		for i = 1, math.floor(math.max(npc.level(), 1)) do
			sbq.upgrades:setTiered("candyBonus", i, 1)
		end
	end
	sbq.settings:setPublicSettings()
	sbq.settings:setStatSettings()

	sbq.init(config.getParameter("sbqConfig"))
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
	sbq.uninit((object.health() > 0) and "uninit" or "died")
	storage.sbqSettings = sbq.settings:save()
	storage.sbqUpgrades = sbq.upgrades:save()
end

function die()
end

function onInteraction(args)
	return sbq.SpeciesScript:interact(args)
end

function sbq.collisionArea()
	return #object.spaces()
end
