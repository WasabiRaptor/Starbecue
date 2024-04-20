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
	if world.entityType(pane.sourceEntity()) == "npc" then
		convertible = world.getNpcScriptParameter(pane.sourceEntity(), "sbqConvertType")
		if convertible then
			_ENV.resultTypeLabel:setText(tostring(convertible))
			_ENV.convertNPCPanel:setVisible(true)
		end
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

function _ENV.convertNPC:onClick()
	world.sendEntityMessage(pane.sourceEntity(), "sbqConvertNPC")
	pane.dismiss()
end

function misc.generateSettingsCard(type)
	return { name = "secretnote", count = 1, parameters = {
		shortdescription = sbq.strings[type.."SettingsCard"] or type.."SettingsCard",
		description = sbq.createdDate(),
		sbqSettings = sbq.getSettingsOf[type]()
	}, }
end
