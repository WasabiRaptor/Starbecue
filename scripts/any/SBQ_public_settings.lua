require "/scripts/any/SBQ_util.lua"
function sbq.setupPublicSettings()
	local entityType = entity.entityType()
	storage = storage or {}
    sbq.config = root.assetJson("/sbq.config")
	sbq.lists = {}
    sbq.voreConfig = root.fetchConfigArray(storage.lastVoreConfig or {})
	sbq.setupSettingMetatables(entityType)

	sbq.refreshPublicSettings()
	sbq.refreshSettings()
end
