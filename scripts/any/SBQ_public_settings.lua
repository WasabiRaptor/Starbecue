require "/scripts/any/SBQ_util.lua"
require "/scripts/any/SBQ_settings.lua"

function sbq.setupPublicSettings()
	sbq.settingsInit()
	message.setHandler("sbqSettingsPageData", function (_,_)
		return {
			settingsPageName = sbq.entityName(entity.id()),
			storageSettings = storage.sbqSettings or {},
			storageUpgrades = storage.sbqUpgrades or {},
			settings = sbq.settings or {},
			voreConfig = sbq.voreConfig or {},
			locations = {},
			currentScale = sbq.scale(),
			parentEntityData = { sbq.parentEntity() },
		}
	end)

	local entityType = entity.entityType()
	storage = storage or {}
	sbq.config = root.assetJson("/sbq.config")
	sbq.lists = {}
	sbq.voreConfig = root.fetchConfigArray(config.getParameter("voreConfig") or {
		hideBehaviorSettings = true,
		hidePredSettings = true
	})
	sbq.setupSettingMetatables(entityType)

	sbq.refreshPublicSettings()
	sbq.refreshSettings()
end
