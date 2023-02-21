---@diagnostic disable: undefined-global

local _init = init
local _update = update
local _onInteraction = onInteraction
local _countTags = countTags

sbq = {}

require("/scripts/SBQ_RPC_handling.lua")

function init()
	sbq.config = root.assetJson("/sbqGeneral.config")

	if not storage.occupier then
		storage = config.getParameter("saveTenants") or {}
		sbq.timer("doRespawn", 0.5, function ()
			respawnTenants()
		end)
	end

	_init()

	message.setHandler("sbqSaveQuestGenSetting", function (_,_, settingname, value, index)
		local scriptConfig = storage.occupier.tenants[index or 1].overrides.scriptConfig or {}
		scriptConfig.questGenerator = {[settingname] = value}
		storage.occupier.tenants[index or 1].overrides.scriptConfig = scriptConfig

		entityId = world.loadUniqueEntity(storage.occupier.tenants[index or 1].uniqueId)

		world.callScriptedEntity(entityId, "tenant.despawn", true)
		sbq.timer("doRespawn", 2, function ()
			respawnTenants()
		end)
	end)

	message.setHandler("sbqSaveSettings", function (_,_, settings, index)
		local scriptConfig = storage.occupier.tenants[index or 1].overrides.scriptConfig or {}
		scriptConfig.sbqSettings = settings
		storage.occupier.tenants[index or 1].overrides.scriptConfig = scriptConfig
	end)

	message.setHandler("sbqSaveTenants", function (_,_, tenants)
		for _, tenant in ipairs(storage.occupier.tenants) do
			if tenant.uniqueId and world.findUniqueEntity(tenant.uniqueId):result() then
				local entityId = world.loadUniqueEntity(tenant.uniqueId)

				world.callScriptedEntity(entityId, "tenant.evictTenant")
			end
		end
		storage.occupier.tenants = tenants

		setTenantsData(storage.occupier)
		sbq.timer("doRespawn", 2, function()
			respawnTenants()
		end)
	end)

	message.setHandler("sbqSavePreySettings", function (_,_, settings, index)
		storage.occupier.tenants[index or 1].overrides.statusControllerSettings.statusProperties.sbqPreyEnabled = settings
	end)
	message.setHandler("sbqSaveDigestedPrey", function (_,_, prey, index)
		storage.occupier.tenants[index or 1].overrides.statusControllerSettings.statusProperties.sbqStoredDigestedPrey = prey
	end)
	message.setHandler("sbqSaveAnimOverrideSettings", function (_,_, settings, index)
		storage.occupier.tenants[index or 1].overrides.statusControllerSettings.statusProperties.speciesAnimOverrideSettings = settings
	end)

	message.setHandler("sbqDeedInteract", function (_,_, args)
		_onInteraction(args)
	end)

	message.setHandler("sbqSummonNewTenant", function (_,_, newTenant, seed)
		if not storage.house then return animator.playSound("error") end

		if not newTenant then return animator.playSound("error") end
		local success, occupier = pcall(root.tenantConfig,(newTenant))
		if not success then return animator.playSound("error") end

		if checkExistingUniqueIds(occupier) then return animator.playSound("error") end
		evictTenants()

		local data = occupier.checkRequirements or {}
		if data.checkItems then
			for i, item in ipairs(data.checkItems) do
				if not root.itemConfig(item) then return end
			end
		end
		if data.checkJson then
			if not pcall(root.assetJson, data.checkJson) then return end
		end
		if data.checkImage then
			success, notEmpty = pcall(root.nonEmptyRegion, data.checkImage)
			if not (success and notEmpty ~= nil) then return end
		end

		if not seeds then
			for _, tenant in ipairs(occupier.tenants) do
				if type(tenant.species) == "table" then
					tenant.species = tenant.species[math.random(#tenant.species)]
				end
				tenant.seed = sb.makeRandomSource():randu64()
			end
		else
			for i, tenant in ipairs(occupier.tenants) do
				tenant.seed = seed[i]
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
end

function update(dt)
	sbq.checkRPCsFinished(dt)
	sbq.checkTimers(dt)
	_update(dt)
end

function countTags(...)
	local tags = _countTags(...)
	tags["sbqVore"] = 1
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
		if data.checkItems then
			for i, item in ipairs(data.checkItems) do
				if not root.itemConfig(item) then return end
			end
		end
		if data.checkJson then
			if not pcall(root.assetJson, data.checkJson) then return end
		end
		if data.checkImage then
			success, notEmpty = pcall(root.nonEmptyRegion, data.checkImage)
			if not (success and notEmpty ~= nil) then return end
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
		if (npcConfig.scriptConfig or {}).uniqueId then
			local id = world.loadUniqueEntity((npcConfig.scriptConfig or {}).uniqueId)
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
		tenant.overrides = tenant.overrides or {}
		tenant.overrides.scriptConfig = tenant.overrides.scriptConfig or {}

		tenant.uniqueId = npcConfig.scriptConfig.uniqueId or sb.makeUuid()
		tenant.overrides.scriptConfig.uniqueId = tenant.uniqueId
		tenant.overrides.scriptConfig.sbqSettings = npcConfig.scriptConfig.sbqDefaultSettings
		tenant.overrides.statusControllerSettings = npcConfig.statusControllerSettings or {}
		tenant.overrides.statusControllerSettings.statusProperties = tenant.overrides.statusControllerSettings.statusProperties or {}

		tenant.seed = sb.makeRandomSource():randu64()
	end
	storage.occupier = occupier
end

function onInteraction(args)
	if not storage.house then return animator.playSound("error") end

	return {"ScriptPane", { data = storage, gui = { }, scripts = {"/metagui/sbq/build.lua"}, ui = "starbecue:voreColonyDeed" }}
end

function die() -- replace the old function so the tenant isn't evicted upon breaking it
	object.setConfigParameter("saveTenants", storage)
	self.questParticipant:die()
	evictTenants()
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
		grumbles[#grumbles + 1] = { "enclosedArea" }
		possibleTortureRoom = true
	else
		storage.house.floorPosition = house.floor
		storage.house.boundary = house.poly

		if liquidInHouseBounds(house.poly) then
			grumbles[#grumbles + 1] = { "tagCriteria" }
			possibleTortureRoom = true
		end
	end

	local scanResults = scanHouseContents(storage.house.boundary)
	if scanResults.otherDeed then
		grumbles[#grumbles + 1] = { "otherDeed" }
	end
	if scanResults.bannedObject then
		grumbles[#grumbles + 1] = { "tagCriteria" }
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
			grumbles[#grumbles + 1] = { "tagCriteria", tag, requiredAmount - currentAmount }
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
	if not storage.occupier then
		return
	end
	for i, tenant in ipairs(storage.occupier.tenants) do
		if not tenant.uniqueId or not world.findUniqueEntity(tenant.uniqueId):result() then
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

	if not overrides.damageTeamType then
		overrides.damageTeamType = "friendly"
	end
	if not overrides.damageTeam then
		overrides.damageTeam = 0
	end
	overrides.persistent = true

	overrides.scriptConfig = overrides.scriptConfig or {}
	overrides.scriptConfig.tenantIndex = i

	local position = { self.position[1], self.position[2] }
	for i, val in ipairs(self.positionVariance) do
		if val ~= 0 then
			position[i] = position[i] + math.random(val) - (val / 2)
		end
	end

	local entityId = nil
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
