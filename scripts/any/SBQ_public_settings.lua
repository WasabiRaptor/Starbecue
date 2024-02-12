require "/scripts/any/SBQ_util.lua"
function sbq.setupPublicSettings()
	local entityType = entity.entityType()
	storage = storage or {}
	sbq.config = root.assetJson("/sbq.config")
    sbq.defaultSettings = sbq.config.entityTypeDefaultSettings[entityType] or { locations = {} }
    sbq.voreConfig = root.fetchConfigArray(storage.lastVoreConfig or {})
	sbq.setupSettingMetatables(entityType)

	for k, v in pairs(sbq.config.publicSettings) do
		if v then sbq.publicSettings[k] = sbq.settings[k] end
    end
    if entityType == "object" then
		object.setConfigParameter("sbqPublicSettings", sbq.publicSettings)
	elseif status ~= nil then
		status.setStatusProperty("sbqPublicSettings", sbq.publicSettings)
	end
end
