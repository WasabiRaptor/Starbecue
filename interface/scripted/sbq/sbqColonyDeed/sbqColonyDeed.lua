---@diagnostic disable: undefined-global
sbq = {
	config = root.assetJson("/sbq.config"),
	strings = root.assetJson("/sbqStrings.config"),
	itemTemplates = root.assetJson("/sbqItemTemplates.config"),

	tenantCatalogue = root.assetJson("/npcs/tenants/sbqTenantCatalogue.json"),
	occupier = metagui.inputData.occupier or {},
	validTenantCatalogueList = {},
	tenantIndex = 0
}
require("/scripts/any/SBQ_RPC_handling.lua")

function init()
	sbq.refreshDeedPage()
	for name, tenantName in pairs(sbq.tenantCatalogue) do
		sbq.populateCatalogueList(name, tenantName)
	end
	table.sort(sbq.validTenantCatalogueList)
	for i, v in ipairs(sbq.validTenantCatalogueList) do
		if v == sbq.occupier.name then
			sbq.tenantIndex = i
		end
	end
	tenantText:setText(sbq.occupier.name or "")
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
	local tenantConfig = root.tenantConfig(tenantName)
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
			if not root.modMetadata(mod) then return end
		end
    end
	if data.checkAssets then
		for i, path in ipairs(data.checkAssets) do
			if not root.assetExists(path) then return end
		end
	end

	table.insert(sbq.validTenantCatalogueList, name)
end

function incTenant:onClick()
	sbq.tenantIndex = sbq.wrapNumber(sbq.tenantIndex +1, 1, #sbq.validTenantCatalogueList)
	tenantText:setText(sbq.validTenantCatalogueList[sbq.tenantIndex])
end

function decTenant:onClick()
	sbq.tenantIndex = sbq.wrapNumber(sbq.tenantIndex -1, 1, #sbq.validTenantCatalogueList)
	tenantText:setText(sbq.validTenantCatalogueList[sbq.tenantIndex])
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

function callTenants:onClick()
	world.sendEntityMessage(pane.sourceEntity(), "sbqDeedInteract", {sourceId = player.id(), sourcePosition = player.position()})
end

local applyCount = 0
function summonTenant:onClick()
	applyCount = applyCount + 1

	if applyCount > 3 or metagui.inputData.occupier == nil then
		world.sendEntityMessage(pane.sourceEntity(), "sbqSummonNewTenant", sbq.getGuardTier() or tenantText.text)
		pane.dismiss()
	end
	self:setText(tostring(4 - applyCount))
end

function sbq.getGuardTier()
	local remap = (sbq.tenantCatalogue[tenantText.text])
	if type(remap) == "table" then
		local tags = metagui.inputData.house.contents
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

function orderFurniture:onClick()
	local occupier = metagui.inputData.occupier
	local contextMenu = {}

	if occupier.name then
		local config = root.tenantConfig(occupier.name)
		occupier.orderFurniture = config.orderFurniture or occupier.orderFurniture
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
			actionLabel = actionLabel.." ^#555;"..sbq.string.price..": ^yellow;"..price.."^reset;"

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
	metagui.contextMenu(contextMenu)
end

function sbq.orderItem(item, price)
	if player.isAdmin() or player.consumeCurrency( "money", price ) then
		player.giveItem(item)
	else
		pane.playSound("/sfx/interface/clickon_error.ogg")
	end
end

--------------------------------------------------------------------------------------------------

function sbq.isValidTenantCard(item)
	if (item.parameters or {}).npcArgs ~= nil then
		if not root.speciesConfig(item.parameters.npcArgs.npcSpecies) then return false end
		if item.parameters.npcArgs.npcParam.wasPlayer then return false end
		if ((item.parameters.npcArgs.npcParam or {}).scriptConfig or {}).uniqueId then
			for i, tenant in ipairs((metagui.inputData.occupier or {}).tenants or {}) do
				if tenant.uniqueId == ((item.parameters.npcArgs.npcParam or {}).scriptConfig or {}).uniqueId then return false end
			end
		end
		return true
	end
end
function uninit()
	local insertTenantItemSlot = _ENV["insertTenantItemSlot"]
	local item = insertTenantItemSlot:item()
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
		uniqueId = ((item.parameters.npcArgs.npcParam or {}).scriptConfig or {}).uniqueId or sb.makeUuid(),
		spawn = item.parameters.npcArgs.npcSpawn or "npc"
	}
	tenant.overrides.scriptConfig = tenant.overrides.scriptConfig or {}
	tenant.overrides.scriptConfig.uniqueId = tenant.uniqueId
	if world.getUniqueEntityId(tenant.uniqueId) then return pane.playSound("/sfx/interface/clickon_error.ogg") end
	slot:setItem(nil, true)
	table.insert(sbq.occupier.tenants, tenant)
	world.sendEntityMessage(pane.sourceEntity(), "sbqSaveTenants", sbq.occupier.tenants)
	sbq.refreshDeedPage()
end

function sbq.refreshDeedPage()
	tenantListScrollArea:clearChildren()

	for i, tenant in ipairs(sbq.occupier.tenants or {}) do
		local name = ((tenant.overrides or {}).identity or {}).name or ""
		local canvasSize = {43,43}
		local portrait = root.npcPortrait("full", tenant.species, tenant.type, tenant.level or 1, tenant.seed, tenant.overrides)
		local id = world.getUniqueEntityId(tenant.uniqueId)
		if id then portrait = world.entityPortrait(id, "full") end

		for k,v in ipairs(portrait) do
			local size = root.imageSize(v.image)
			canvasSize = {math.max(size[1],canvasSize[1]),math.max(size[2],canvasSize[2])}
		end
		local panel = { type = "panel", expandMode = { 0, 2 }, style = "flat", children = {
			{ mode = "vertical" },
			{ type = "canvas", id = "tenant" .. i .. "Canvas", size = canvasSize },
			{ type = "label", text = name, align = "center" },
			{ type = "button", caption = ":settings", id = "tenant" .. i .. "Settings", size = canvasSize[1]},
			{ type = "button", caption = ":remove", color = "FF0000", id = "tenant" .. i .. "Remove", size = canvasSize[1] }
		} }
		tenantListScrollArea:addChild(panel)
		local canvasWidget = _ENV["tenant" .. i .. "Canvas"]
		local canvas = widget.bindCanvas( canvasWidget.backingWidget )
		local remove = _ENV["tenant" .. i .. "Remove"]
		local settings = _ENV["tenant" .. i .. "Settings"]
		function remove:onClick()
			local item = sbq.generateNPCItemCard(tenant)
			sb.logInfo("Removed Tenant:"..sb.printJson(tenant,2))
			player.giveItem(item)
			table.remove(metagui.inputData.occupier.tenants, i)
			world.sendEntityMessage(metagui.inputData.respawner or pane.sourceEntity(), "sbqSaveTenants", metagui.inputData.occupier.tenants)
			sbq.refreshDeedPage()
		end
		for k,v in ipairs(portrait) do
			local pos = v.position or {0, 0}
			canvas:drawImage(v.image, {pos[1] + canvasSize[1]/2, pos[2] + canvasSize[2]/2}, 1, nil, true )
		end
		function settings:onClick()
			local id = world.getUniqueEntityId(tenant.uniqueId)
			if not id then pane.playSound("/sfx/interface/clickon_error.ogg") return end
			sbq.addRPC(world.sendEntityMessage(id, "getEntitySettingsMenuData", player.id()), function(data)
				player.interact("ScriptPane", { gui = {}, scripts = { "/metagui/sbq/build.lua" }, data = data, ui =  ("starbecue:entitySettings") }, id)
			end, function ()
				pane.playSound("/sfx/interface/clickon_error.ogg")
			end)
		end
	end
	tenantListScrollArea:addChild({ type="panel", style="flat", id="insertTenantPanel", expandMode={0,0}, children={
		{ type="itemSlot", id="insertTenantItemSlot", autoInteract=true },
		{ type="button", id="insertTenant", caption=":insertCard" }
	} })

	local insertTenant = _ENV["insertTenant"]
	local insertTenantItemSlot = _ENV["insertTenantItemSlot"]
	function insertTenant:onClick()
		sbq.insertTenant(insertTenantItemSlot)
	end
	function insertTenantItemSlot:acceptsItem(item)
		if not sbq.isValidTenantCard(item) then pane.playSound("/sfx/interface/clickon_error.ogg") return false
		else return true end
	end

	orderFurniture:setVisible(sbq.occupier.orderFurniture ~= nil)

	tenantText:setText(sbq.occupier.name or "")
	local tags = metagui.inputData.house.contents
	local listed = { sbqVore = true }
	requiredTagsScrollArea:clearChildren()
	local colonyTagLabels = {}
	for tag, value in pairs(sbq.occupier.tagCriteria or {}) do
		if tag ~= "sbqVore" then
			listed[tag] = true
			local amount = tags[tag] or 0
			local string = "^green;" .. tag .. ": " .. amount
			if amount < value then
				string = "^red;" .. tag .. ": " .. amount .. " ^yellow;"..sbq.strings.tagsNeeds..": " .. value
			end
			table.insert(colonyTagLabels, { type = "label", text = string })
		end
	end
	for tag, value in pairs(tags or {}) do
		if not listed[tag] then
			table.insert(colonyTagLabels, { type = "label", text = tag .. ": " .. value })
		end
	end
	requiredTagsScrollArea:addChild({ type = "panel", style = "flat", children = colonyTagLabels })
end

function sbq.generateNPCItemCard(tenant)
	local npcConfig = root.npcConfig(tenant.type)

	local item = sb.jsonMerge(sbq.itemTemplates.npcCard,{})

	if npcConfig.scriptConfig.isOC then
		item.parameters.rarity = "rare"
	elseif npcConfig.scriptConfig.sbqNPC then
		item.parameters.rarity = "uncommon"
	end

	item.parameters.shortdescription = ((tenant.overrides or {}).identity or {}).name or ""
	item.parameters.inventoryIcon = root.npcPortrait("bust", tenant.species, tenant.type, tenant.level or 1, tenant.seed, tenant.overrides)
	item.parameters.description = (npcConfig.scriptConfig or {}).cardDesc or ""
	item.parameters.tooltipFields.collarNameLabel = ""
	item.parameters.tooltipFields.objectImage = root.npcPortrait("full", tenant.species, tenant.type, tenant.level or 1, tenant.seed, tenant.overrides)
	item.parameters.tooltipFields.subtitle = tenant.type
	item.parameters.tooltipFields.collarIconImage = nil
	item.parameters.npcArgs = {
		npcSpecies = tenant.species,
		npcSeed = tenant.seed,
		npcType = tenant.type,
		npcLevel = tenant.level,
		npcParam = tenant.overrides,
		npcSpawn = tenant.spawn
	}
	item.parameters.preySize = 1
	return item
end
