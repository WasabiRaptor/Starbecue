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
		_ENV.upgradesGrid:addSlot({name = "sbqCandy", count = 1, parameters = {level = v[1], bonus = v[2], seed = sb.makeRandomSource():randu64()}})
	end
	local entityType = world.entityType(pane.sourceEntity())
	if entityType == "npc" then
		convertType = world.getNpcScriptParameter(pane.sourceEntity(), "sbqConvertType")
		if convertType and (world.npcType(pane.sourceEntity()) ~= convertType) then
			_ENV.resultTypeLabel:setText(convertType)
			_ENV.convertNPCPanel:setVisible(true)
		end
		if sbq.cosmeticSlots and world.getNpcScriptParameter(pane.sourceEntity(), "sbqNPC") then
			_ENV.npcCosmeticSlots:setVisible(true)
			for k, v in pairs(sbq.cosmeticSlots) do
				_ENV[k]:setItem(v)
			end
			_ENV.customizeNPC:setVisible(world.getNpcScriptParameter(pane.sourceEntity(), "sbqIsCustomizable") or false)
		end
	elseif entityType == "object" then
		_ENV.stripping:setVisible(world.getObjectParameter(pane.sourceEntity(), "hasCosmeticSlots") or false)
		_ENV.statBars:setVisible(false)
	end
	local source = sbq.entityId()
	_ENV.healthBar.parent:setVisible(world.entityIsResource(source, "health") or false)
	_ENV.hungerBar.parent:setVisible(world.entityIsResource(source, "food") or false)
	_ENV.lustBar.parent:setVisible(world.entityIsResource(source, "sbqLust") or false)
	_ENV.restBar.parent:setVisible(world.entityIsResource(source, "sbqRest") or false)
end

function update()
	local source = sbq.entityId()
	if world.entityIsResource(source, "health") then
		_ENV.healthBar:setValue(world.entityResourcePercentage(source, "health"))
	end
	if world.entityIsResource(source, "food") then
		_ENV.hungerBar:setValue(world.entityResourcePercentage(source,"food"))
	end
	if world.entityIsResource(source, "sbqLust") then
		_ENV.lustBar:setValue(world.entityResourcePercentage(source,"sbqLust"))
	end
	if world.entityIsResource(source, "sbqRest") then
		_ENV.restBar:setValue(world.entityResourcePercentage(source,"sbqRest"))
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
				"sbqGetTieredUpgrade",
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

function misc.generateSettingsCard(type)
	local settings = sbq.getSettingsOf[type]()
	sbq.logInfo("Exported"..type.."settings")
	sbq.logInfo(settings,2)
	return { name = "secretnote", count = 1, parameters = {
		shortdescription = sbq.entityName(sbq.entityId()).." "..(sbq.strings[type.."SettingsCard"] or type.."SettingsCard"),
		description = sbq.getString(":"..type.."settingsCardDesc"),
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

_ENV.headCosmetic.acceptsItem = misc.cosmeticAcceptsItem
_ENV.chestCosmetic.acceptsItem = misc.cosmeticAcceptsItem
_ENV.legsCosmetic.acceptsItem = misc.cosmeticAcceptsItem
_ENV.backCosmetic.acceptsItem = misc.cosmeticAcceptsItem

_ENV.headCosmetic.onItemModified = misc.cosmeticUpdated
_ENV.chestCosmetic.onItemModified = misc.cosmeticUpdated
_ENV.legsCosmetic.onItemModified = misc.cosmeticUpdated
_ENV.backCosmetic.onItemModified = misc.cosmeticUpdated

function _ENV.customizeNPC:onClick()
	player.setScriptContext("starbecue")
	player.callScript("sbq.customizeEntity", pane.sourceEntity())
end
