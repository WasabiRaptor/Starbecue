function init()
    local candiesEaten = storage.sbqUpgrades.candiesEaten or {}
	local candies = {}
	for i, v in pairs(candiesEaten) do
		table.insert(candies, {tonumber(i),v})
    end
	table.sort(candies, function (a, b)
		return a[1] < b[1]
    end)
	for _, v in ipairs(candies) do
		_ENV.upgradesGrid:addSlot({name = "sbqCandy", count = 1, parameters = {level = v[1], bonus = v[2]}})
	end
end
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
misc = {}

function _ENV.exportAllSettings:onClick()
	player.giveItem(misc.generateSettingsCard("all"))
end
function _ENV.exportPrefsOnly:onClick()
	player.giveItem(misc.generateSettingsCard("prefs"))
end
function _ENV.exportLocationsOnly:onClick()
	player.giveItem(misc.generateSettingsCard("locations"))
end

function misc.generateSettingsCard(type)
    return { name = "secretnote", count = 1, parameters = {
		shortdescription = sbq.strings[type.."SettingsCard"] or type.."SettingsCard",
        description = sbq.createdDate(),
		sbqSettings = misc.getSettingsOf[type]()
    }, }
end
misc.getSettingsOf = {}
function misc.getSettingsOf.prefs()
    local merged = sb.jsonMerge(sbq.defaultSettings, storage.sbqSettings, sbq.settings)
    return {
        vorePrefs = merged.vorePrefs,
		infusePrefs = merged.infusePrefs
	}
end
function misc.getSettingsOf.locations()
    local merged = sb.jsonMerge(sbq.defaultSettings, storage.sbqSettings, sbq.settings)
    return {
        locations = merged.locations,
	}
end
function misc.getSettingsOf.all()
    return sb.jsonMerge(sbq.defaultSettings, storage.sbqSettings, sbq.settings)
end
