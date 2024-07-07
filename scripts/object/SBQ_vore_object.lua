sbq = {}
require"/scripts/any/SBQ_RPC_handling.lua"
require"/scripts/any/SBQ_override_dummies.lua"
require"/scripts/any/SBQ_vore_main.lua"
require"/scripts/any/SBQ_rewards.lua"
require"/scripts/any/SBQ_dialogue.lua"
require"/scripts/any/SBQ_dialogue_scripts.lua"

function init()
	sbq.config = root.assetJson("/sbq.config")
	sbq.facingDirection = object.direction

	sbq.entityId = entity.id

	sbq.say = object.say
	sbq.sayPortrait = object.sayPortrait

	sbq.setProperty = object.setConfigParameter

	storage.baseStats = sbq.initStats(config.getParameter("stats") or {})
	storage.effectCategories = sb.jsonMerge(config.getParameter("effectCategories") or {}, storage.effectCategories or {})
	storage.stats = storage.stats or {}
	sbq.calculateStats()
	storage.resourceData = config.getParameter("resources") or {}
	storage.resources = sb.jsonMerge(sbq.getDefaultResources(), storage.resources or {})
	storage.resourcesLocked = storage.resourcesLocked or {}

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

function onInteraction(args)
	return SpeciesScript:interact(args)
end

function sbq.area()
	return #object.spaces()
end
