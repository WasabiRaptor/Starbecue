
storage = _ENV.metagui.inputData or {}
local mg = metagui ---@diagnostic disable-line: undefined-global

if storage.locked and (storage.lockOwner ~= player.uniqueId()) and not player.isAdmin() then
	sbq.playErrorSound()
	interface.queueMessage(sbq.getString(":targetOwned"))
	pane.dismiss()
end

require "/interface/scripted/sbq/colonyDeed/generateItemCard.lua"

local drawable
function init()
	drawable = pane.drawable()
	sbq.refreshDeedPage()
	_ENV.lockedDeed:setChecked(storage.locked or false)
	_ENV.hiddenDeed:setChecked(storage.hidden or false)
end

function update()
	local dt = script.updateDt()
	sbq.checkRPCsFinished(dt)
	sbq.checkTimers(dt)
end

function _ENV.callTenants:onClick()
	world.sendEntityMessage(pane.sourceEntity(), "sbqDeedInteract", {sourceId = player.id(), sourcePosition = world.entityPosition(player.id())})
end

local applyCount = 4
function _ENV.summonTenant:onClick()

	if (applyCount == 1) or (storage.occupier == nil) then
		self:setText(tostring(0))
		local menu = {}
		for _, v in ipairs(root.assetJson("/interface/scripted/sbq/colonyDeed/catalogue.config")) do
			if type(v) == "table" then
				table.insert(menu, {
					v[1],
					function ()
						world.sendEntityMessage(pane.sourceEntity(), "sbqSummonNewTenant", v[2])
						pane.dismiss()
					end,
				})
			else
				table.insert(menu, v)
			end
		end
		_ENV.metagui.dropDownMenu(menu, 4)
	else
		applyCount = applyCount - 1
		self:setText(tostring(applyCount))
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
			actionLabel = actionLabel.." ^#555;"..sbq.getString(":price")..": ^yellow;"..price.."^reset;"

			local comma = ""
			local gotReqTag = false
			for reqTag, value in pairs(occupier.tagCriteria or {}) do
				for j, tag in ipairs(itemConfig.config.colonyTags or {}) do
					if tag == reqTag then
						if not gotReqTag then
							actionLabel = actionLabel.." ^#555;"..sbq.getString(":tags")..":"
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

function sbq.insertTenant(item)
	if not item then return end
	local tenant = {
		species = item.parameters.npcArgs.npcSpecies,
		seed = item.parameters.npcArgs.npcSeed,
		type = item.parameters.npcArgs.npcType,
		level = item.parameters.npcArgs.npcLevel,
		overrides = item.parameters.npcArgs.npcParam or {},
		spawn = item.parameters.npcArgs.npcSpawn or "npc"
	}
	local npcConfig = root.npcConfig(tenant.type)
	local deedConvertKey = (storage.evil and "sbqEvilDeedConvertType") or "sbqDeedConvertType"
	if npcConfig.scriptConfig[deedConvertKey] then
		tenant.type = npcConfig.scriptConfig[deedConvertKey]
		npcConfig = root.npcConfig(tenant.type)
	end

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
	storage.occupier.orderFurniture = nil
	for i, tenant in ipairs(storage.occupier.tenants or {}) do
		local name = ((tenant.overrides or {}).identity or {}).name or ""
		local portrait
		local id = world.uniqueEntityId(tenant.uniqueId)
		if id then
			portrait = world.entityPortrait(id, "full")
		else
			portrait = root.npcPortrait("full", tenant.species, tenant.type, tenant.level or 1, tenant.seed, tenant.overrides)
		end
		local canvasSize = {43,60}
		if portrait then
			local bounds = rect.size(drawable.boundBoxAll(portrait, true))
			canvasSize = { math.max(canvasSize[1], bounds[1]), math.max(canvasSize[2], bounds[2]) }
		end
		canvasSize[1] = math.max(canvasSize[1], mg.measureString(name)[1])
		if tenant.stolenBy then
			canvasSize[1] = math.max(canvasSize[1], mg.measureString(tenant.stolenBy)[1])
		end
		if tenant.orderFurniture then
			storage.occupier.orderFurniture = storage.occupier.orderFurniture or jarray()
			for _, v in ipairs(tenant.orderFurniture) do
				table.insert(storage.occupier.orderFurniture,v)
			end
		end

		local panel = { type = "panel", expandMode = { 0, 0 }, style = "flat", color = (not id) and "FF0000", children = {
			{ mode = "vertical", expandMode = { 0, 0 } },
			{ type = "canvas", id = "tenant" .. i .. "Canvas", size = canvasSize, expandMode = { 0, 0 } },
			{
				{ expandMode = { 0, 0 }},
				{ type = "label", text = name, align = "center", inline = true },
				{ type = "iconButton", id = "tenant" .. i.. "Customize", image = "/interface/scripted/sbq/customize.png", toolTip = ":customize", visible = id and world.getNpcScriptParameter(id, "sbqIsCustomizable") or false }
			},
			{ type = "button", caption = ":settings", id = "tenant" .. i .. "Settings", size = {canvasSize[1],15}, expandMode = { 0, 0 }},
			{ type = "label", id = "tenant" .. i .. "Stolen", text = sbq.getString(":stolenBy"):format(tenant.stolenBy), align = "center", inline = true, width = canvasSize[1] },
			{ type = "button", caption = ":restore", color = "00FF00",  id = "tenant" .. i .. "Restore", size = {canvasSize[1],15},  expandMode = { 0, 0 }},
			{ type = "button", caption = ":remove", color = "FF0000", id = "tenant" .. i .. "Remove", size = {canvasSize[1],15}, expandMode = { 0, 0 } },
		} }
		_ENV.tenantListScrollArea:addChild(panel)
		local canvasWidget = _ENV["tenant" .. i .. "Canvas"]
		local canvas = widget.bindCanvas( canvasWidget.backingWidget )
		local remove = _ENV["tenant" .. i .. "Remove"]
		local restore = _ENV["tenant" .. i .. "Restore"]
		local stolenLabel = _ENV["tenant" .. i .. "Stolen"]
		local settings = _ENV["tenant" .. i .. "Settings"]
		local customize = _ENV["tenant" .. i .. "Customize"]
		restore:setVisible(tenant.stolenBy and true or false)
		stolenLabel:setVisible(tenant.stolenBy and true or false)
		settings:setVisible(not tenant.stolenBy and true or false)
		function remove:onClick()
			local item = sbq.generateNPCItemCard(tenant)
			sb.logInfo("Removed Tenant:"..sb.printJson(tenant,2))
			player.giveItem(item)
			table.remove(storage.occupier.tenants, i)
			world.sendEntityMessage(storage.respawner or pane.sourceEntity(), "sbqSaveTenants", storage.occupier.tenants)
			sbq.refreshDeedPage()
		end
		function restore:onClick()
			tenant.stolenBy = nil
			world.sendEntityMessage(storage.respawner or pane.sourceEntity(), "sbqSaveTenants", storage.occupier.tenants)
			sbq.refreshDeedPage()
		end
		canvas:clear()
		if portrait then
			local bounds = drawable.boundBoxAll(portrait, true)
			local center = rect.center(bounds)
			canvas:drawJsonDrawables(portrait, vec2.sub(vec2.div(canvasWidget.size, 2), center))
		end
		function settings:onClick()
			local id = world.uniqueEntityId(tenant.uniqueId)
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
			local id = world.uniqueEntityId(tenant.uniqueId)
			if not id then sbq.playErrorSound() return end
			world.sendEntityMessage(player.id(), "sbqCustomizeEntity", id)
		end

	end
	_ENV.tenantListScrollArea:addChild({ type="panel", style="flat", id="insertTenantPanel", expandMode={0,0}, children={
		{ type = "itemSlot", id = "insertTenantItemSlot", autoInteract = true },
		 {type = "label", text = ":insertCard" }
	} })
	function _ENV.insertTenantItemSlot:acceptsItem(item)
		if not sbq.isValidTenantCard(item) then
			sbq.playErrorSound()
			return false
		else
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
				interface.queueMessage(sbq.getString(":invalidNPC"))
				return false
			end
			local deedConvertKey = (storage.evil and "sbqEvilDeedConvertType") or "sbqDeedConvertType"
			if npcConfig.scriptConfig[deedConvertKey] then
				tenant.type = npcConfig.scriptConfig[deedConvertKey]
				npcConfig = root.npcConfig(tenant.type)
			end
			if storage.evil and npcConfig.scriptConfig.requiresFriendly then
				sbq.playErrorSound()
				interface.queueMessage(sbq.getString(":requiresFriendly"))
				return false
			elseif (not storage.evil) and npcConfig.scriptConfig.requiresEvil then
				sbq.playErrorSound()
				interface.queueMessage(sbq.getString(":requiresEvil"))
				return false
			end
			local overrideConfig = sb.jsonMerge(npcConfig, tenant.overrides)
			tenant.overrides.scriptConfig.uniqueId = sbq.query(overrideConfig, {"scriptConfig", "uniqueId"}) or sb.makeUuid()
			tenant.uniqueId = tenant.overrides.scriptConfig.uniqueId
			if world.uniqueEntityId(tenant.uniqueId) then
				sbq.playErrorSound()
				interface.queueMessage(sbq.getString(":npcAlreadyExists"))
				return false
			end
			for _, v in pairs(storage.occupier.tenants) do
				if v.uniqueId == tenant.uniqueId then
					sbq.playErrorSound()
					interface.queueMessage(sbq.getString(":npcAlreadyExists"))
					return false
				end
			end
			return true
		end
	end
	function _ENV.insertTenantItemSlot:onItemModified()
		sbq.insertTenant(self:item())
	end

	_ENV.orderFurniture:setVisible(storage.occupier.orderFurniture ~= nil)

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
