function init()
	for i, v in ipairs(sbq.upgrades.storedUpgrades.candyBonus or {}) do
		if v > 0 then
			_ENV.upgradesGrid:addSlot({name = "sbqCandy", count = 1, parameters = {level = i, bonus = v, seed = sb.makeRandomSource():randu64()}})
		end
	end
	local entityType = world.entityType(sbq.entityId())
	_ENV.upgradeInputPanel:setVisible(not sbq.settings.settingsConfig.hideUpgrades)
	_ENV.upgradePanel:setVisible(not sbq.settings.settingsConfig.hideUpgrades)
	_ENV.stripping:setVisible(not sbq.settings.settingsConfig.hideStripping)

	if entityType == "npc" then
		convertType = world.getNpcScriptParameter(sbq.entityId(), "sbqConvertType")
		if convertType and (world.npcType(sbq.entityId()) ~= convertType) then
			_ENV.resultTypeLabel:setText(convertType)
			_ENV.convertNPCPanel:setVisible(true)
		end
		for k, v in pairs(sbq.cosmeticSlots) do
			_ENV[k]:setItem(v)
		end
		_ENV.customizeNPC:setVisible(world.getNpcScriptParameter(sbq.entityId(), "sbqIsCustomizable") or false)
	elseif entityType == "object" then
		_ENV.npcCosmeticSlots:setVisible(false)
		_ENV.stripping:setVisible(world.getObjectParameter(sbq.entityId(), "hasCosmeticSlots") or false)
		_ENV.statBars:setVisible(false)
	elseif entityType == "player" then
		_ENV.npcCosmeticSlots:setVisible(false)
		_ENV.upgradeInputPanel:setVisible(false)
		_ENV.miscOtherPlayerLayout:clearChildren()
		_ENV.miscOtherPlayerLayout:addChild({ type = "sbqSetting", setting = "scrollText", makeLabel = true })
		_ENV.miscOtherPlayerLayout:addChild({ type = "sbqSetting", setting = "customFont", makeLabel = true })
	end
	local source = sbq.entityId()
	_ENV.healthBar.parent:setVisible(world.entity(source):isResource("health") or false)
	_ENV.hungerBar.parent:setVisible(world.entity(source):isResource("food") or false)
	_ENV.lustBar.parent:setVisible(world.entity(source):isResource("sbqLust") or false)
	_ENV.restBar.parent:setVisible(world.entity(source):isResource("sbqRest") or false)
end

function update()
	local source = sbq.entityId()
	if world.entity(source):isResource("health") then
		_ENV.healthBar:setValue(world.entity(source):resourcePercentage("health"))
	end
	if world.entity(source):isResource("food") then
		_ENV.hungerBar:setValue(world.entity(source):resourcePercentage("food"))
	end
	if world.entity(source):isResource("sbqLust") then
		_ENV.lustBar:setValue(world.entity(source):resourcePercentage("sbqLust"))
	end
	if world.entity(source):isResource("sbqRest") then
		_ENV.restBar:setValue(world.entity(source):resourcePercentage("sbqRest"))
	end
end

function uninit()
	local item = _ENV.importSettingsSlot:item()
	if item then player.giveItem(item) end
end

function _ENV.upgradeInput:acceptsItem(item)
	if not item then return false end
	local itemConfig = root.itemConfig(item)
	if itemConfig and itemConfig.config.sbqTieredUpgrade then
		return true
	else
		sbq.playErrorSound()
		return false
	end
end

function _ENV.upgradeInput:onItemModified()
	local item = self:item()
	if item then
		local itemConfig = root.itemConfig(item)
		if itemConfig.config.sbqTieredUpgrade then
			world.sendEntityMessage(
				pane.sourceEntity(),
				"sbqSetTieredUpgrade",
				itemConfig.config.sbqTieredUpgrade,
				itemConfig.config.level or itemConfig.parameters.level or 1,
				itemConfig.config.bonus or itemConfig.parameters.bonus or 1
			)
			self:setItem(nil, true)
		end
	end
end


function _ENV.importSettingsSlot:acceptsItem(item)
	if (item.parameters or {}).sbqSettings then
		return true
	else
		sbq.playErrorSound()
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

local exportFilters = {
	prefs = {
		vorePrefs = true,
		infusePrefs = true,
		subBehavior = true,
		domBehavior = true
	},
	locations = {
		locations = true
	}
}

function misc.generateSettingsCard(filter)
	local settings = sbq.settings:export(exportFilters[filter])
	sbq.logInfo(settings,2)
	return { name = "secretnote", count = 1, parameters = {
		shortdescription = sbq.entityName(sbq.entityId()).." "..(sbq.strings[filter.."SettingsCard"] or filter.."SettingsCard"),
		description = sbq.getString(":"..filter.."settingsCardDesc"),
		sbqSettings = settings,
		tooltipKind = "filledcapturepod",
		tooltipFields = {
			noCollarLabel = "",
			collarNameLabel = sbq.createdDateString(),
			objectImage = world.entityPortrait(sbq.entityId(), "full")
		}
	}, }
end

local cosmeticItemType = {
	headCosmetic = "headarmor",
	chestCosmetic = "chestarmor",
	legsCosmetic = "legsarmor",
	backCosmetic = "backarmor"
}

function misc.cosmeticAcceptsItem(slot, item)
	if not item then return true end
	return root.itemType(item.name) == cosmeticItemType[slot.id]
end
function misc.cosmeticUpdated(slot)
	world.sendEntityMessage(pane.sourceEntity(), "sbqUpdateCosmeticSlot", slot.id, slot:item())
end
function misc.acceptAnyCosmetic(slot, item)
	if not item then return true end
	local itemType = root.itemType(item.name)
	return (itemType == "headarmor") or (itemType == "chestarmor") or (itemType == "legsarmor") or (itemType == "backarmor")
end

_ENV.headCosmetic.acceptsItem = misc.cosmeticAcceptsItem
_ENV.chestCosmetic.acceptsItem = misc.cosmeticAcceptsItem
_ENV.legsCosmetic.acceptsItem = misc.cosmeticAcceptsItem
_ENV.backCosmetic.acceptsItem = misc.cosmeticAcceptsItem

_ENV.headCosmetic.onItemModified = misc.cosmeticUpdated
_ENV.chestCosmetic.onItemModified = misc.cosmeticUpdated
_ENV.legsCosmetic.onItemModified = misc.cosmeticUpdated
_ENV.backCosmetic.onItemModified = misc.cosmeticUpdated

_ENV.cosmetic1.onItemModified = misc.cosmeticUpdated
_ENV.cosmetic2.onItemModified = misc.cosmeticUpdated
_ENV.cosmetic3.onItemModified = misc.cosmeticUpdated
_ENV.cosmetic4.onItemModified = misc.cosmeticUpdated
_ENV.cosmetic5.onItemModified = misc.cosmeticUpdated
_ENV.cosmetic6.onItemModified = misc.cosmeticUpdated
_ENV.cosmetic7.onItemModified = misc.cosmeticUpdated
_ENV.cosmetic8.onItemModified = misc.cosmeticUpdated
_ENV.cosmetic9.onItemModified = misc.cosmeticUpdated
_ENV.cosmetic10.onItemModified = misc.cosmeticUpdated
_ENV.cosmetic11.onItemModified = misc.cosmeticUpdated
_ENV.cosmetic12.onItemModified = misc.cosmeticUpdated

_ENV.cosmetic1.acceptsItem = misc.acceptAnyCosmetic
_ENV.cosmetic2.acceptsItem = misc.acceptAnyCosmetic
_ENV.cosmetic3.acceptsItem = misc.acceptAnyCosmetic
_ENV.cosmetic4.acceptsItem = misc.acceptAnyCosmetic
_ENV.cosmetic5.acceptsItem = misc.acceptAnyCosmetic
_ENV.cosmetic6.acceptsItem = misc.acceptAnyCosmetic
_ENV.cosmetic7.acceptsItem = misc.acceptAnyCosmetic
_ENV.cosmetic8.acceptsItem = misc.acceptAnyCosmetic
_ENV.cosmetic9.acceptsItem = misc.acceptAnyCosmetic
_ENV.cosmetic10.acceptsItem = misc.acceptAnyCosmetic
_ENV.cosmetic11.acceptsItem = misc.acceptAnyCosmetic
_ENV.cosmetic12.acceptsItem = misc.acceptAnyCosmetic

function _ENV.customizeNPC:onClick()
	world.sendEntityMessage(player.id(), "sbqCustomizeEntity", pane.sourceEntity())
end
