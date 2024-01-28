require "/scripts/SBQ_util.lua"
function sbq.setupPublicSettings()
	storage = storage or {}
	sbq.config = root.assetJson("/sbq.config")
    sbq.defaultSettings = sbq.config.entityTypeDefaultSettings[entity.entityType()] or { locations = {} }
	sbq.voreConfig = sbq.getConfigArray(storage.lastVoreConfig or {})
	sbq.setupSettingMetatables(entity.entityType())

	for k, v in pairs(sbq.config.publicSettings) do
		if v then sbq.publicSettings[k] = sbq.settings[k] end
	end
	status.setStatusProperty("sbqPublicSettings", sbq.publicSettings)
end
