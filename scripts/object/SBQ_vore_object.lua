require"/scripts/any/SBQ_override_dummies.lua"
require"/scripts/any/SBQ_vore_main.lua"
require"/scripts/any/SBQ_rewards.lua"
require"/scripts/any/SBQ_dialogue.lua"
require"/scripts/any/SBQ_dialogue_scripts.lua"

function sbq.initObject()
	sbq.facingDirection = object.direction

	sbq.entityId = entity.id

	sbq.say = object.say
	sbq.sayPortrait = object.sayPortrait

	sbq.setProperty = object.setConfigParameter

	sbq.lastVoreConfig = config.getParameter("voreConfig")
	storage.baseStats = config.getParameter("stats") or {}
	storage.effectCategories = sb.jsonMerge(config.getParameter("effectCategories") or {}, storage.effectCategories or {})
	storage.stats = storage.stats or {}
	sbq.calculateStats()
	storage.resourceData = config.getParameter("resources") or {}
	storage.resources = sb.jsonMerge(sbq.getDefaultResources(), storage.resources or {})
	storage.resourcesLocked = storage.resourcesLocked or {}
end

function sbq.area()
	return #object.spaces()
end
