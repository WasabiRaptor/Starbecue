
storage = _ENV.metagui.inputData or {}
if storage.locked and (storage.lockOwner ~= player.uniqueId()) and not player.isAdmin() then
	sbq.playErrorSound()
	player.queueUIMessage(sbq.getString(":targetOwned"))
	pane.dismiss()
end

require "/interface/scripted/sbq/colonyDeed/generateItemCard.lua"

sbq.tenantCatalogue = root.assetJson("/npcs/sbq/sbqTenantCatalogue.json")
sbq.validTenantCatalogueList = {}
sbq.tenantIndex = 0

function init()
	sbq.refreshDeedPage()
	for name, tenantName in pairs(sbq.tenantCatalogue) do
		sbq.populateCatalogueList(name, tenantName)
	end
	table.sort(sbq.validTenantCatalogueList)
	for i, v in ipairs(sbq.validTenantCatalogueList) do
		if v == (storage.occupier or {}).name then
			sbq.tenantIndex = i
		end
	end
	_ENV.tenantText:setText((storage.occupier or {}).name or "")
	_ENV.lockedDeed:setChecked(storage.locked or false)
	_ENV.hiddenDeed:setChecked(storage.hidden or false)
end

function update()
	local dt = script.updateDt()
	sbq.checkRPCsFinished(dt)
	sbq.checkTimers(dt)
end

function sbq.populateCatalogueList(name, tenantName)
	local tenantName = tenantName
	if type(tenantName) == "table" then
		tenantName = tenantName[1]
	end
	local success, tenantConfig = pcall(root.tenantConfig, tenantName)
	if not success then sbq.logError(("Invalid tenant entry in SBQ deed catalogue: %s, %s"):format(name, tenantName)) return end

	local data = tenantConfig.checkRequirements or {}
	for i, tenant in ipairs(tenantConfig.tenants) do
		if tenant.spawn == "npc" then
			for _, species in ipairs(tenant.species) do
				if not root.speciesConfig(species) then return end
			end
		end
	end
	if data.checkItems then
		for i, item in ipairs(data.checkItems) do
			if not root.itemConfig(item) then return end
		end
	end
	if data.checkMods then
		for i, mod in ipairs(data.checkMods) do
			if not root.assetSourceMetadata(mod) then return end
		end
	end
	if data.checkAssets then
		for i, path in ipairs(data.checkAssets) do
			if not root.assetOrigin(path) then return end
		end
	end
	if storage.evil and (tenantConfig.colonyTagCriteria.sbqFriendly) then
		return
	elseif (not storage.evil) and (tenantConfig.colonyTagCriteria.sbqEvil) then
		return
	end

	table.insert(sbq.validTenantCatalogueList, name)
end

function _ENV.incTenant:onClick()
	sbq.tenantIndex = sbq.wrapNumber(sbq.tenantIndex +1, 1, #sbq.validTenantCatalogueList)
	_ENV.tenantText:setText(sbq.validTenantCatalogueList[sbq.tenantIndex])
end

function _ENV.decTenant:onClick()
	sbq.tenantIndex = sbq.wrapNumber(sbq.tenantIndex -1, 1, #sbq.validTenantCatalogueList)
	_ENV.tenantText:setText(sbq.validTenantCatalogueList[sbq.tenantIndex])
end
function sbq.wrapNumber(input, min, max)
	if input > max then
		return min
	elseif input < min then
		return max
	else
		return input
	end
end

function _ENV.callTenants:onClick()
	world.sendEntityMessage(pane.sourceEntity(), "sbqDeedInteract", {sourceId = player.id(), sourcePosition = world.entityPosition(player.id())})
end

local applyCount = 0
function _ENV.summonTenant:onClick()
	applyCount = applyCount + 1

	if applyCount > 3 or storage.occupier == nil then
		world.sendEntityMessage(pane.sourceEntity(), "sbqSummonNewTenant", sbq.getGuardTier() or _ENV.tenantText.text)
		pane.dismiss()
	end
	self:setText(tostring(4 - applyCount))
end

function sbq.getGuardTier()
	local remap = (sbq.tenantCatalogue[_ENV.tenantText.text])
	if type(remap) == "table" then
		local tags = storage.house.contents
		local index = 1
		if type(tags.tier2) == "number" and tags.tier2 >= 12 then
			index = 2
		end
		if type(tags.tier3) == "number" and tags.tier3 >= 12 then
			index = 3
		end
		if type(tags.tier4) == "number" and tags.tier4 >= 12 then
			index = 3
		end
		return remap[index]
	else
		return remap
	end
end

--------------------------------------------------------------------------------------------------

function _ENV.orderFurniture:onClick()
	local occupier = storage.occupier
	local contextMenu = {}

	if occupier.name then
		local success, config = pcall(root.tenantConfig, (occupier.name))
		if success then
			occupier.orderFurniture = config.orderFurniture or occupier.orderFurniture
		end
	end


	for i, item in pairs(occupier.orderFurniture or {}) do
		local itemConfig = root.itemConfig(item)
		if not itemConfig then
			sb.logInfo(item.name.." can't be ordered: doesn't exist")
		elseif (type(item.price) ~= "number" and type((itemConfig.config or {}).price) ~= "number") then
			sb.logInfo(item.name.." can't be ordered: has no price")
		else
			local actionLabel = itemConfig.config.shortdescription.."^reset;"
			if item.count ~= nil and item.count > 1 then
				actionLabel = actionLabel.." x"..item.count
			end
			if type((item.parameters or {}).color) == "string" then
				actionLabel = "^"..item.parameters.color..";"..actionLabel
			end

			local price = ((item.count or 1)*(item.price or itemConfig.config.price))
			actionLabel = actionLabel.." ^#555;"..sbq.strings.price..": ^yellow;"..price.."^reset;"

			local comma = ""
			local gotReqTag = false
			for reqTag, value in pairs(occupier.tagCriteria or {}) do
				for j, tag in ipairs(itemConfig.config.colonyTags or {}) do
					if tag == reqTag then
						if not gotReqTag then
							actionLabel = actionLabel.." ^#555;"..sbq.strings.tags..":"
							gotReqTag = true
						end
						actionLabel = actionLabel..comma.." ^green;"..tag.."^reset;"
						comma = "^#555;,^reset;"
						break
					end
				end
			end

			table.insert(contextMenu, {actionLabel, function () sbq.orderItem(item, price) end})
		end
	end
	_ENV.metagui.contextMenu(contextMenu)
end

function sbq.orderItem(item, price)
	if player.isAdmin() or player.consumeCurrency( "money", price ) then
		player.giveItem(item)
	else
		sbq.playErrorSound()
	end
end

--------------------------------------------------------------------------------------------------

function sbq.isValidTenantCard(item)
	if (item.parameters or {}).npcArgs ~= nil then
		if not root.speciesConfig(sbq.query(item, {"parameters", "npcArgs", "npcSpecies"})) then return false end
		if sbq.query(item, {"parameters", "npcArgs", "npcParam", "wasPlayer"}) then return false end
		local uuid = sbq.query(item, {"parameters", "npcArgs", "npcParam", "scriptConfig", "uniqueId"})
		if uuid then
			for i, tenant in ipairs((storage.occupier or {}).tenants or {}) do
				if tenant.uniqueId == uuid then return false end
			end
		end
		return true
	end
end
function uninit()
	local item = _ENV.insertTenantItemSlot:item()
	if item then
		player.giveItem(item)
	end
end

function sbq.insertTenant(slot)
	local item = slot:item()
	local tenant = {
		species = item.parameters.npcArgs.npcSpecies,
		seed = item.parameters.npcArgs.npcSeed,
		type = item.parameters.npcArgs.npcType,
		level = item.parameters.npcArgs.npcLevel,
		overrides = item.parameters.npcArgs.npcParam or {},
		spawn = item.parameters.npcArgs.npcSpawn or "npc"
	}
	local npcConfig = root.npcConfig(tenant.type)
	if not npcConfig then
		sbq.playErrorSound()
		player.queueUIMessage(sbq.getString(":invalidNPC"))
		return
	end
	local deedConvertKey = (storage.evil and "sbqEvilDeedConvertType") or "sbqDeedConvertType"
	if npcConfig.scriptConfig[deedConvertKey] then
		tenant.type = npcConfig.scriptConfig[deedConvertKey]
		npcConfig = root.npcConfig(tenant.type)
	end
	if storage.evil and npcConfig.scriptConfig.requiresFriendly then
		sbq.playErrorSound()
		player.queueUIMessage(sbq.getString(":requiresFriendly"))
		return
	elseif (not storage.evil) and npcConfig.scriptConfig.requiresEvil then
		sbq.playErrorSound()
		player.queueUIMessage(sbq.getString(":requiresEvil"))
		return
	end
	local overrideConfig = sb.jsonMerge(npcConfig, tenant.overrides)
	tenant.overrides.scriptConfig.uniqueId = sbq.query(overrideConfig, {"scriptConfig", "uniqueId"}) or sb.makeUuid()
	tenant.uniqueId = tenant.overrides.scriptConfig.uniqueId
	if world.getUniqueEntityId(tenant.uniqueId) then
		sbq.playErrorSound()
		player.queueUIMessage(sbq.getString(":npcAlreadyExists"))
		return
	end
	for _, v in pairs(storage.occupier.tenants) do
		if v.uniqueId == tenant.uniqueId then
			sbq.playErrorSound()
			player.queueUIMessage(sbq.getString(":npcAlreadyExists"))
			return
		end
	end
	slot:setItem(nil, true)
	table.insert(storage.occupier.tenants, tenant)
	world.sendEntityMessage(pane.sourceEntity(), "sbqSaveTenants", storage.occupier.tenants)
	sbq.refreshDeedPage()
end

local specialDeedTags = {
	sbqVore = true,
	sbqHouse = true,
	sbqCamp = true,
	sbqFriendly = true,
	sbqEvil = true,
	sbqBoss = true
}
function sbq.refreshDeedPage()
	_ENV.tenantListScrollArea:clearChildren()
	if not storage.occupier then return end
	for i, tenant in ipairs(storage.occupier.tenants or {}) do
		local name = ((tenant.overrides or {}).identity or {}).name or ""
		local portrait = root.npcPortrait("full", tenant.species, tenant.type, tenant.level or 1, tenant.seed, tenant.overrides)
		local id = world.getUniqueEntityId(tenant.uniqueId)
		if id then portrait = world.entityPortrait(id, "full") end
		local canvasSize = {43,60}
		if portrait then
			local bounds = rect.size(sb.drawableBoundBox(portrait,true))
			canvasSize = {math.max(canvasSize[1], bounds[1]), math.max(canvasSize[2], bounds[2])}
		end
		local panel = { type = "panel", expandMode = { 0, 0 }, style = "flat", children = {
			{ mode = "vertical", expandMode = { 0, 0 } },
			{ type = "canvas", id = "tenant" .. i .. "Canvas", size = canvasSize, expandMode = { 0, 0 } },
			{
				{ expandMode = { 0, 0 }},
				{ type = "label", text = name, align = "center", inline = true },
				{ type = "iconButton", id = "tenant" .. i.. "Customize", image = "/interface/scripted/sbq/customize.png", toolTip = ":customize", visible = world.getNpcScriptParameter(id, "sbqIsCustomizable") or false }
			},
			{ type = "button", caption = ":settings", id = "tenant" .. i .. "Settings", size = canvasSize[1], expandMode = { 0, 0 }},
			{ type = "button", caption = ":remove", color = "FF0000", id = "tenant" .. i .. "Remove", size = canvasSize[1], expandMode = { 0, 0 } }
		} }
		_ENV.tenantListScrollArea:addChild(panel)
		local canvasWidget = _ENV["tenant" .. i .. "Canvas"]
		local canvas = widget.bindCanvas( canvasWidget.backingWidget )
		local remove = _ENV["tenant" .. i .. "Remove"]
		local settings = _ENV["tenant" .. i .. "Settings"]
		local customize = _ENV["tenant" .. i .. "Customize"]
		function remove:onClick()
			local item = sbq.generateNPCItemCard(tenant)
			sb.logInfo("Removed Tenant:"..sb.printJson(tenant,2))
			player.giveItem(item)
			table.remove(storage.occupier.tenants, i)
			world.sendEntityMessage(storage.respawner or pane.sourceEntity(), "sbqSaveTenants", storage.occupier.tenants)
			sbq.refreshDeedPage()
		end
		canvas:clear()
		if portrait then
			canvas:drawDrawables(portrait, vec2.div(canvasWidget.size, 2))
		end
		function settings:onClick()
			local id = world.getUniqueEntityId(tenant.uniqueId)
			if not id then sbq.playErrorSound() return end
			sbq.addRPC(world.sendEntityMessage(id, "sbqSettingsPageData", player.id()), function(data)
				if (not data) or ((not player.isAdmin()) and data.parentEntityData[2] and (entity.uniqueId() ~= data.parentEntityData[1])) then
					sbq.playErrorSound()
				end
				player.interact("ScriptPane", { gui = {}, scripts = { "/metagui/sbq/build.lua" }, data = {sbq = data}, ui =  ("starbecue:entitySettings") }, id)
			end, function ()
				sbq.playErrorSound()
			end)
		end
		function customize:onClick()
			local id = world.getUniqueEntityId(tenant.uniqueId)
			if not id then sbq.playErrorSound() return end
			player.setScriptContext("starbecue")
			player.callScript("sbq.customizeEntity", id)
		end

	end
	_ENV.tenantListScrollArea:addChild({ type="panel", style="flat", id="insertTenantPanel", expandMode={0,0}, children={
		{ type="itemSlot", id="insertTenantItemSlot", autoInteract=true },
		{ type="button", id="insertTenant", caption=":insertCard" }
	} })

	function _ENV.insertTenant:onClick()
		sbq.insertTenant(_ENV.insertTenantItemSlot)
	end
	function _ENV.insertTenantItemSlot:acceptsItem(item)
		if not sbq.isValidTenantCard(item) then sbq.playErrorSound() return false
		else return true end
	end

	_ENV.orderFurniture:setVisible(storage.occupier.orderFurniture ~= nil)

	_ENV.tenantText:setText(storage.occupier.name or "")
	local tags = storage.house.contents
	local listed = { sbqVore = true }
	_ENV.requiredTagsScrollArea:clearChildren()
	local colonyTagLabels = {}
	for tag, value in pairs(storage.occupier.tagCriteria or {}) do
		local amount = tags[tag] or 0
		if tag == "sbqHouse" then
			table.insert(colonyTagLabels, { type = "label", text = (
				((amount < value) and ("^red;") or ("^green;")).. sbq.getString(":requiresHouse")
			) })
		elseif tag == "sbqCamp" then
			table.insert(colonyTagLabels, { type = "label", text = (
				((amount < value) and ("^red;") or ("^green;")).. sbq.getString(":requiresCamp")
			) })
		elseif tag == "sbqFriendly" then
			table.insert(colonyTagLabels, { type = "label", text = (
				((amount < value) and ("^red;") or ("^green;")).. sbq.getString(":requiresFriendly")
			) })
		elseif tag == "sbqEvil" then
			table.insert(colonyTagLabels, { type = "label", text = (
				((amount < value) and ("^red;") or ("^green;")).. sbq.getString(":requiresEvil")
			) })
		elseif tag == "sbqBoss" then
			table.insert(colonyTagLabels, { type = "label", text = (
				((amount < value) and ("^red;") or ("^green;")).. sbq.getString(":requiresBoss")
			) })
		elseif tag ~= "sbqVore" then
			listed[tag] = true
			table.insert(colonyTagLabels, { type = "label", text = (
				(amount < value) and ("^red;" .. tag .. ": " .. amount .. " ^yellow;" .. (sbq.getString(":tagsNeeds")) .. ": " .. value)
				or ("^green;" .. tag .. ": " .. amount)
			) })
		end
	end
	for tag, value in pairs(tags or {}) do
		if not listed[tag] and not specialDeedTags[tag] then
			table.insert(colonyTagLabels, { type = "label", text = tag .. ": " .. value })
		end
	end
	_ENV.requiredTagsScrollArea:addChild({ type = "panel", style = "flat", children = colonyTagLabels })
end

--------------------------------------------------------------------------------------------------

function _ENV.lockedDeed:onClick()
	world.sendEntityMessage(pane.sourceEntity(), "sbqLockDeed", self.checked, player.uniqueId())
end
function _ENV.hiddenDeed:onClick()
	world.sendEntityMessage(pane.sourceEntity(), "sbqHideDeed", self.checked)
end
