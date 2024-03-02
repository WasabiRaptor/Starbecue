function uninit()
    local item = _ENV.importSettingsSlot:item()
	if item then player.giveItem(item) end
end

function _ENV.importSettingsSlot:acceptsItem(item)
	if (item.parameters or {}).sbqSettings then
        return true
    else
        pane.playSound("/sfx/interface/clickon_error.ogg")
		return false
	end
end

function _ENV.importSettings:onClick()
	local item = _ENV.importSettingsSlot:item()
	if item then
		sbq.importSettings((item.parameters or {}).sbqSettings)
	end
end

function _ENV.exportAllSettings:onClick()
	player.giveItem(sbq.generateSettingsCard("all"))
end
function _ENV.exportPrefsOnly:onClick()
	player.giveItem(sbq.generateSettingsCard("prefs"))
end
function _ENV.exportLocationsOnly:onClick()
	player.giveItem(sbq.generateSettingsCard("locations"))
end

function sbq.generateSettingsCard(type)
    return { name = "secretnote", count = 1, parameters = {
		shortdescription = sbq.strings[type.."SettingsCard"] or type.."SettingsCard",
        description = os.date(sbq.strings.createdOnDate, os.time()),
		sbqSettings = sbq.getSettingsOf[type]()
    }, }
end
sbq.getSettingsOf = {}
function sbq.getSettingsOf.prefs()
    local merged = sb.jsonMerge(sbq.defaultSettings, storage.sbqSettings, sbq.settings)
    return {
        vorePrefs = merged.vorePrefs,
		infusePrefs = merged.infusePrefs
	}
end
function sbq.getSettingsOf.locations()
    local merged = sb.jsonMerge(sbq.defaultSettings, storage.sbqSettings, sbq.settings)
    return {
        locations = merged.locations,
	}
end
function sbq.getSettingsOf.all()
    return sb.jsonMerge(sbq.defaultSettings, storage.sbqSettings, sbq.settings)
end
