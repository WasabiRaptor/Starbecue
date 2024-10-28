---@diagnostic disable: undefined-global
local old = {
	init = init,
	update = update,
	onInteraction = onInteraction,
	countTags = countTags,
	die = die
}

sbq = {}

require("/scripts/any/SBQ_RPC_handling.lua")
require"/scripts/any/SBQ_util.lua"

sbqTenant = {}
function sbqTenant:setSetting(k, v)
	self.overrides.scriptConfig.sbqSettings = self.overrides.scriptConfig.sbqSettings or {}
	self.overrides.scriptConfig.sbqSettings[k] = v
end
function sbqTenant:setGroupedSetting(group, name, k, v)
	self.overrides.scriptConfig.sbqSettings = self.overrides.scriptConfig.sbqSettings or {}
	self.overrides.scriptConfig.sbqSettings[group] = self.overrides.scriptConfig.sbqSettings[group] or {}
	self.overrides.scriptConfig.sbqSettings[group][name] = self.overrides.scriptConfig.sbqSettings[group][name] or {}
	self.overrides.scriptConfig.sbqSettings[group][name][k] = v
end
function sbqTenant:importSettings(newSettings)
	self.overrides.scriptConfig.sbqSettings = newSettings
end
function sbqTenant:getUpgrade(upgradeName, tier, bonus)
	self.overrides.scriptConfig.sbqUpgrades = self.overrides.scriptConfig.sbqUpgrades or {}
	self.overrides.scriptConfig.sbqUpgrades[upgradeName] = self.overrides.scriptConfig.sbqUpgrades[upgradeName] or {}
	self.overrides.scriptConfig.sbqUpgrades[upgradeName][tier] = math.max(self.overrides.scriptConfig.sbqUpgrades[upgradeName][tier] or 0, bonus)
end

function init()
	sbq.config = root.assetJson("/sbq.config")

	if not storage.occupier then
		storage = config.getParameter("scriptStorage") or {}
		sbq.timer("doRespawn", 0.5, function ()
			respawnTenants()
		end)
	end

	storage.evil = config.getParameter("evil")
	storage.linkTeams = config.getParameter("linkTeams")
	storage.damageTeamType = storage.damageTeamType or config.getParameter("damageTeamType")
	storage.damageTeam = storage.damageTeam or math.random(10,255)
	old.init()

	message.setHandler("sbqParentSetSetting", function(_, _, recruitUuid, uuid, ...)
		local i = findTenant(uuid)
		if not i then return end
		sbqTenant.setSetting(storage.occupier.tenants[i], ...)
	end)
	message.setHandler("sbqParentSetGroupedSetting", function(_, _, recruitUuid, uuid, ...)
		local i = findTenant(uuid)
		if not i then return end
		sbqTenant.setGroupedSetting(storage.occupier.tenants[i], ...)
	end)
	message.setHandler("sbqParentGetUpgrade", function(_, _, recruitUuid, uuid, ...)
		local i = findTenant(uuid)
		if not i then return end
		sbqTenant.getUpgrade(storage.occupier.tenants[i], ...)
	end)
	message.setHandler("sbqParentImportSettings", function(_, _, recruitUuid, uuid, ...)
		local i = findTenant(uuid)
		if not i then return end
		sbqTenant.importSettings(storage.occupier.tenants[i], ...)
	end)
	message.setHandler("sbqParentUpdateType", function(_, _, recruitUuid, uuid, ...)
		_ENV.replaceTenant(uuid, ...)
	end)


	message.setHandler("sbqSaveTenants", function(_, _, tenants)
		local uniqueTenants = {}
		for _, tenant in ipairs(tenants) do
			if tenant.uniqueId then
				uniqueTenants[tenant.uniqueId] = true
			end
		end
		for _, tenant in ipairs(storage.occupier.tenants) do
			if tenant.uniqueId and not uniqueTenants[tenant.uniqueId] then
				local entityId = world.loadUniqueEntity(tenant.uniqueId)
				if entityId and world.entityExists(entityId) then
					world.callScriptedEntity(entityId, "tenant.evictTenant")
				end
			end
		end
		storage.occupier.tenants = tenants

		setTenantsData(storage.occupier)
		sbq.timer("doRespawn", 2, function()
			respawnTenants()
		end)
	end)

	message.setHandler("sbqDeedInteract", function (_,_, args)
		old.onInteraction(args)
	end)

	message.setHandler("sbqSummonNewTenant", function (_,_, newTenant, seeds)
		if not storage.house then return animator.playSound("error") end

		if not newTenant then return animator.playSound("error") end
		local success, occupier = pcall(root.tenantConfig,(newTenant))
		if not success then return animator.playSound("error") end

		if storage.evil and (occupier.colonyTagCriteria.sbqFriendly) then
			return animator.playSound("error")
		elseif (not storage.evil) and (occupier.colonyTagCriteria.sbqEvil) then
			return animator.playSound("error")
		end

		if checkExistingUniqueIds(occupier) then return animator.playSound("error") end
		evictTenants()

		local data = occupier.checkRequirements or {}
		for i, tenant in ipairs(occupier.tenants) do
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
		if not seeds then
			for _, tenant in ipairs(occupier.tenants) do
				if type(tenant.species) == "table" then
					tenant.species = tenant.species[math.random(#tenant.species)]
				end
				tenant.seed = tenant.seed or sb.makeRandomSource():randu64()
			end
		else
			for i, tenant in ipairs(occupier.tenants) do
				tenant.seed = tenant.seed or seed[i]
			end
		end

		setTenantsData(occupier)

		if isOccupied() then
			respawnTenants()
			animator.setAnimationState("particles", "newArrival")
			sendNewTenantNotification()
			return
		end
	end)
	message.setHandler("sbqHideDeed", function (_,_,hidden)
		storage.hidden = hidden
		animator.setGlobalTag("directives", storage.hidden and "?multiply=FFFFFF20" or "")
	end)
	message.setHandler("sbqLockDeed", function(_, _, locked, uuid)
		local wasLocked = storage.locked
		if storage.locked or storage.lockOwner then
			if storage.lockOwner == uuid then
				storage.locked = locked
			end
		else
			storage.locked = locked
			storage.lockOwner = uuid
		end
		if not storage.locked then
			storage.lockOwner = nil
		end
		if wasLocked ~= storage.locked then
			evictTenants()
			respawnTenants()
		end
	end)

	animator.setGlobalTag("directives", storage.hidden and "?multiply=FFFFFF20" or "")
end

function update(dt)
	sbq.checkRPCsFinished(dt)
	sbq.checkTimers(dt)
	old.update(dt)
	if sbq.timer("output", 1) then
		setOutput()
	end
end

function countTags(...)
	local tags = old.countTags(...)
	for _, v in ipairs(config.getParameter("sbqTags")) do
		tags[v] = (tags[v] or 0) + 1
	end
	if storage.linkTeams and storage.isTeamBoss then
		tags.sbqBoss = 1
	end
	return tags
end

function chooseTenants(seed, tags)
	if seed then
		math.randomseed(seed)
	end

	local matches = root.getMatchingTenants(tags)
	local highestPriority = 0
	for _, tenant in ipairs(matches) do
		if tenant.priority > highestPriority then
			highestPriority = tenant.priority
		end
	end

	matches = util.filter(matches, function(match)

		local data = match.checkRequirements or {}
		for i, tenant in ipairs(match.tenants) do
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

		if checkExistingUniqueIds(match) then return end

		return (match.priority >= highestPriority)
	end)
	util.debugLog("Applicable tenants:")
	for _, tenant in ipairs(matches) do
		util.debugLog("  " .. tenant.name .. " (priority " .. tenant.priority .. ")")
	end

	if #matches == 0 then
		util.debugLog("Failed to find a suitable tenant")
		return
	end

	setTenantsData(matches[math.random(#matches)])

	if seed then
		math.randomseed(util.seedTime())
	end
end

function checkExistingUniqueIds(occupier)
	for _, tenant in ipairs(occupier.tenants) do
		local npcConfig = root.npcConfig(tenant.type)
		local uuid = sbq.query(npcConfig, {"scriptConfig", "uniqueId"})
		if uuid then
			local id = world.loadUniqueEntity(uuid)
			if id and world.entityExists(id) then return true end
		end
	end
end


function setTenantsData(occupier)
	local occupier = occupier
	for _, tenant in ipairs(occupier.tenants) do
		if type(tenant.species) == "table" then
			tenant.species = tenant.species[math.random(#tenant.species)]
		end
		local npcConfig = root.npcConfig(tenant.type)
		local deedConvertKey = (storage.evil and "sbqEvilDeedConvertType") or "sbqDeedConvertType"
		if npcConfig.scriptConfig[deedConvertKey] then
			tenant.type = npcConfig.scriptConfig[deedConvertKey]
			npcConfig = root.npcConfig(tenant.type)
		end
		local overrideConfig = sb.jsonMerge(npcConfig, tenant.overrides or {})
		tenant.uniqueId = sbq.query(overrideConfig, {"scriptConfig", "uniqueId"}) or sb.makeUuid()
		tenant.overrides = tenant.overrides or {}
		tenant.overrides.scriptConfig = tenant.overrides.scriptConfig or {}
		tenant.overrides.scriptConfig.uniqueId = tenant.uniqueId
		tenant.seed = tenant.seed or sb.makeRandomSource():randu64()
	end
	storage.occupier = occupier
end

function onInteraction(args)
	if not storage.house then return animator.playSound("error") end

	return {"ScriptPane", { data = storage, gui = { }, scripts = {"/metagui/sbq/build.lua"}, ui = "starbecue:colonyDeed" }}
end

function checkHouseIntegrity()
	storage.grumbles, storage.possibleTortureRoom = scanHouseIntegrity()

	for _, tenant in ipairs(storage.occupier.tenants) do
		if tenant.uniqueId and world.findUniqueEntity(tenant.uniqueId):result() then
			local entityId = world.loadUniqueEntity(tenant.uniqueId)

			world.callScriptedEntity(entityId, "tenant.setGrumbles", storage.grumbles)
		end
	end

	if #storage.grumbles > 0 and isGrumbling() and self.grumbleTimer:complete() and storage.possibleTortureRoom then
		evictTenants()
	end
end

function scanHouseIntegrity()
	if not world.regionActive(polyBoundBox(storage.house.boundary)) then
		util.debugLog("Parts of the house are unloaded - skipping integrity check")
		return storage.grumbles or {}, storage.possibleTortureRoom
	end

	local possibleTortureRoom

	local grumbles = {}
	local house = findHouseBoundary(self.position, self.maxPerimeter)

	if not house.poly then
		table.insert(grumbles, { "enclosedArea" })
		possibleTortureRoom = true
	else
		storage.house.floorPosition = house.floor
		storage.house.boundary = house.poly

		if liquidInHouseBounds(house.poly) then
			table.insert(grumbles, { "enclosedArea" })
			possibleTortureRoom = true
		end
	end

	local scanResults = scanHouseContents(storage.house.boundary)
	if scanResults.otherDeed then
		table.insert(grumbles, { "otherDeed" })
	end
	if scanResults.bannedObject then
		table.insert(grumbles, { "enclosedArea" })
		possibleTortureRoom = true
	end

	local objects = countObjects(scanResults.objects, house.doors or {})
	storage.house.objects = storage.house.objects or {}
	for objectName, count in pairs(objects) do
		local oldCount = storage.house.objects[objectName] or 0
		if count > oldCount then
			self.questParticipant:fireEvent("objectAdded", objectName, count - oldCount)
		end
	end
	for objectName, count in pairs(storage.house.objects) do
		local newCount = objects[objectName] or 0
		if newCount < count then
			self.questParticipant:fireEvent("objectRemoved", objectName, count - newCount)
		end
	end
	storage.house.objects = objects

	local tags = countTags(scanResults.objects, house.doors or {})
	storage.house.contents = tags
	for tag, requiredAmount in pairs(getTagCriteria()) do
		local currentAmount = tags[tag] or 0
		if currentAmount < requiredAmount then
			table.insert(grumbles, { "tagCriteria", tag, requiredAmount - currentAmount })
		end
	end

	return grumbles, possibleTortureRoom
end

function liquidInHouseBounds(poly)
	local box = util.boundBox(poly)
	local liquidFill = world.liquidAt({box[1]+1, box[2]+1, box[3]-1, box[4]-1})
	if liquidFill and liquidFill[2] > 0.5 then return true end -- Room is over halfway full of liquid
	if self.position ~= nil then
		local position = findFloor(self.position, 10)
		if not position then return true end

		return world.liquidAt({position[1]-3, position[2]+0, position[1]+3, position[2]+5})
	end
	return true
end

function scanVacantArea()
	local house = findHouseBoundary(self.position, self.maxPerimeter)

	local housePolyActive = house.poly and world.regionActive(polyBoundBox(house.poly))

	if housePolyActive and liquidInHouseBounds(house.poly) then
		util.debugLog("Liquid at NPC spawn position")
		animator.setAnimationState("deedState", "error")
	elseif housePolyActive then
		local scanResults = scanHouseContents(house.poly)
		if scanResults.otherDeed then
			util.debugLog("Colony deed is already present")
		elseif scanResults.objects then
			if scanResults.bannedObject then
				util.debugLog("House contains dangerous objects")
				animator.setAnimationState("deedState", "error")
				return
			end

			local tags = countTags(scanResults.objects, house.doors)
			storage.house = {
				boundary = house.poly,
				contents = tags,
				seed = scanResults.hash,
				floorPosition = house.floor,
				objects = countObjects(scanResults.objects, house.doors)
			}
			local seed = nil
			if self.hashHouseAsSeed then
				seed = scanResults.hash
			end
			chooseTenants(seed, tags)

			if isOccupied() then
				respawnTenants()
				animator.setAnimationState("particles", "newArrival")
				sendNewTenantNotification()
				return
			end
		end
	elseif not house.poly then
		util.debugLog("Scan failed")
		animator.setAnimationState("deedState", "error")
	else
		util.debugLog("Parts of the house are unloaded - skipping scan")
	end
end

function respawnTenants()
	if not storage.occupier then return end
	-- if wired, don't respawn tenants when not powered
	if object.isInputNodeConnected(0) and not object.getInputNodeLevel(0) then return end

	for i, tenant in ipairs(storage.occupier.tenants) do
		local doSpawn = false
		if tenant.uniqueId then
			local eid = world.loadUniqueEntity(tenant.uniqueId)
			if eid then
				if not world.entityExists(eid) then
					doSpawn = true
				end
			else
				doSpawn = true
			end
		else
			doSpawn = true
		end
		if doSpawn and not tenant.replacing then
			local entityId = spawn(tenant, i)
			tenant.uniqueId = tenant.uniqueId or sb.makeUuid()
			world.setUniqueId(entityId, tenant.uniqueId)

			world.callScriptedEntity(entityId, "tenant.setHome", storage.house.floorPosition, storage.house.boundary, deedUniqueId())
		end
	end
end

function spawn(tenant, i)
	local level = tenant.level or getRentLevel()
	tenant.overrides = tenant.overrides or {}
	local overrides = tenant.overrides

	overrides.damageTeamType = storage.damageTeamType or "friendly"
	overrides.damageTeam = storage.damageTeam or 0

	overrides.persistent = true

	overrides.scriptConfig = overrides.scriptConfig or {}
	overrides.scriptConfig.tenantIndex = i
	overrides.podUuid = storage.lockOwner

	local position = { self.position[1], self.position[2] }
	for i, val in ipairs(self.positionVariance) do
		if val ~= 0 then
			position[i] = position[i] + math.random(val) - (val / 2)
		end
	end

	local entityId = nil
	if tenant.uniqueId and world.findUniqueEntity(tenant.uniqueId):result() then
		return world.loadUniqueEntity(tenant.uniqueId)
	end
	if tenant.spawn == "npc" then
		entityId = world.spawnNpc(position, tenant.species, tenant.type, level, tenant.seed, overrides)
		if tenant.personality then
			world.callScriptedEntity(entityId, "setPersonality", tenant.personality)
		else
			tenant.personality = world.callScriptedEntity(entityId, "personality")
		end
		if not tenant.storedIdentity then
			tenant.overrides.identity = world.callScriptedEntity(entityId, "npc.humanoidIdentity")
			tenant.storedIdentity = true
		end
	elseif tenant.spawn == "monster" then
		if not overrides.seed and tenant.seed then
			overrides.seed = tenant.seed
		end
		if not overrides.level then
			overrides.level = level
		end
		entityId = world.spawnMonster(tenant.type, position, overrides)

	else
		if tenant.spawn then
			sb.logInfo("colonydeed can't be used to spawn entity type '" .. tenant.spawn .. "'")
		else
			sb.logInfo("no spawn type")
		end
		return nil
	end

	if tenant.seed == nil then
		tenant.seed = world.callScriptedEntity(entityId, "object.seed")
	end
	return entityId
end

function die()
	-- Spawn NPC essence for all tenants
	-- for _, tenant in pairs(((storage or {}).occupier or {}).tenants or {}) do
	-- 	local item = sbq.generateNPCItemCard(tenant)
	-- 	if item then
	-- 		world.spawnItem(item, object.position())
	-- 	end
	-- end
	-- Original function will fail quests and evict tenants
	old.die()
	-- Dropped deed is empty
	-- storage = {}
end

function setDeedDamageTeam(source, type, team)
	if storage.linkTeams then
		storage.damageTeamType = type
		storage.damageTeam = team
		for _, tenant in ipairs((storage.occupier or {}).tenants or {}) do
			if tenant.uniqueId then
				local entityId = world.loadUniqueEntity(tenant.uniqueId)
				if entityId and world.entityExists(entityId) then
					world.callScriptedEntity(entityId, world.entityType(entityId) .. ".setDamageTeam", {
						type = storage.damageTeamType,
						team = storage.damageTeam,
					})
				end
			end
		end
		for _, v in ipairs(object.getOutputNodeConnections(0)) do
			local id, connection = table.unpack(v)
			if id ~= source then
				world.callScriptedEntity(id, "setDeedDamageTeam", entity.id(), type, team)
			end
		end
		for _, v in ipairs(object.getInputNodeConnections(0)) do
			local id, connection = table.unpack(v)
			if id ~= source then
				world.callScriptedEntity(id, "setDeedDamageTeam", entity.id(), type, team)
			end
		end
	end
end
function isLinkedSBQDeed()
	return storage.linkTeams
end

function setOutput()
	local tenantsAlive = false
	for _, tenant in ipairs((storage.occupier or {}).tenants or {}) do
		if tenant.uniqueId and world.findUniqueEntity(tenant.uniqueId):result() then
			tenantsAlive = true
		end
	end
	object.setOutputNodeLevel(0, ((not object.isInputNodeConnected(0)) or object.getInputNodeLevel(0)) and tenantsAlive)
end

function onNodeConnectionChange()
	local inputIds = object.getInputNodeConnections(0)
	if #inputIds ~= storage.inputCount then
		storage.inputCount = #inputIds
		storage.isTeamBoss = true
		storage.linkedDeed = nil
		for k, v in ipairs(inputIds) do
			local id, connection = table.unpack(v)
			if world.callScriptedEntity(id, "isLinkedSBQDeed") then
				storage.linkedDeed = id
				storage.isTeamBoss = false
				break
			end
		end
		if storage.isTeamBoss and storage.linkTeams then
			setDeedDamageTeam(storage.linkedDeed or entity.id(), storage.damageTeamType, math.random(10,255))
		end
	end
	local outputIds = object.getOutputNodeConnections(0)
	if #outputIds ~= storage.outputCount then
		storage.outputCount = #outputIds
		for _, v in ipairs(outputIds) do
			local id, connection = table.unpack(v)
			world.callScriptedEntity(id, "setDeedDamageTeam", entity.id(), storage.damageTeamType, storage.damageTeam)
		end
	end
	setOutput()
end
function onInputNodeChange(args)
	setOutput()
end

require "/interface/scripted/sbq/colonyDeed/generateItemCard.lua"
