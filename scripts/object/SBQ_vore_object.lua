function sbq.initObject()
	sbq.facingDirection = object.direction

    sbq.say = object.say
    sbq.sayPortrait = object.sayPortrait

    sbq.setProperty = object.setConfigParameter

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
