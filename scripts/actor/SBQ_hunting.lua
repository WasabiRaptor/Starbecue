function sbq.getPreyWilling(voreTypes)
	local favoredVoreTypes = sbq.getFavoredVoreTypes("prey", preySettings, healOrDigest)
	if not favoredVoreTypes[1] then return false end
	local favoredSelection = {
		favoredVoreTypes[math.random(#favoredVoreTypes)],
		favoredVoreTypes[math.random(#favoredVoreTypes)],
		favoredVoreTypes[math.random(#favoredVoreTypes)],
		favoredVoreTypes[math.random(#favoredVoreTypes)]
	}
	for i, voreType in ipairs(voreTypes) do
		for j, voreType2 in ipairs(favoredSelection) do
			if voreType == voreType2 then return true end
		end
	end
	return false
end

function sbq.doTargetAction()
	if not storage.huntingTarget then return end
	if not sbq.timer("targetReachedCooldown", storage.huntingTarget.combat and 1 or 5) then return end
	if npc.loungingIn() ~= nil and (status.statusProperty("sbqType") ~= "driver") then
		storage.huntingTarget = nil
		self.board:setEntity("sbqHuntingTarget", nil)
		sbq.targetedEntities = {}
		return
	end
	sbq.logInfo("Trying action: " .. sb.printJson(storage.huntingTarget))
	if storage.huntingTarget.combat then
		if storage.huntingTarget.predOrPrey == "pred" then
			sbq.combatEat()
		end
	else
		if storage.huntingTarget.predOrPrey == "pred" then
			if storage.huntingTarget.getConsent then
				sbq.askToVore()
			else
				sbq.eatUnprompted()
			end
		elseif storage.huntingTarget.predOrPrey == "prey" then
			if storage.huntingTarget.getConsent then
				sbq.askToBeVored()
			else
				sbq.forcePrey()
			end
		end
	end
end

function sbq.askToVore()
	entityType = world.entityType(storage.huntingTarget.id)
	if entityType == "player" then
		if sbq.timer("leaveUnresponsivePlayer", 30, function ()
			sbq.getNextTarget()
		end) then
			local dialogueBoxData = sbq.getDialogueBoxData()
			dialogueBoxData.dialogueTreeStart = ".vore"
			dialogueBoxData.settings = sb.jsonMerge(dialogueBoxData.settings, {
				voreType = storage.huntingTarget.voreType,
				voreResponse = "selfRequest"
			})
			world.sendEntityMessage(storage.huntingTarget.id, "sbqOpenMetagui", "starbecue:dialogueBox", entity.id(), dialogueBoxData )
		end
	elseif entityType == "npc" then
		local settings = sb.jsonMerge(storage.settings, {
			voreType = storage.huntingTarget.voreType,
			voreResponse = "selfRequest"
		})
		sbq.getRandomDialogue(".vore", storage.huntingTarget.id, settings)
		local options = sb.jsonMerge(dialogue.result.options or {}, {})
		sbq.addNamedRPC("sbqNPCGetConsent",
			world.sendEntityMessage(storage.huntingTarget.id, "sbqNPCGetConsent", entity.id(), storage.huntingTarget),
			function(result)
				if result == 1 then
					settings.willing = true
				end
				sbq.getRandomDialogue((((options or {})[result] or {})[2] or {}), storage.huntingTarget.id, settings)
				if result == 2 then -- "No."
					sbq.getNextTarget()
				end
			end)
	elseif entityType == "monster" then
		sbq.eatUnprompted()
	end
end

function sbq.askToBeVored()
	entityType = world.entityType(storage.huntingTarget.id)
	if entityType == "player" then
		if sbq.timer("leaveUnresponsivePlayer", 30, function ()
			sbq.getNextTarget()
		end) then
			local dialogueBoxData = sbq.getDialogueBoxData()
			dialogueBoxData.dialogueTreeStart = ".preyRequest"
			dialogueBoxData.settings = sb.jsonMerge(dialogueBoxData.settings, {
				voreType = storage.huntingTarget.voreType,
			})
			world.sendEntityMessage(storage.huntingTarget.id, "sbqOpenMetagui", "starbecue:dialogueBox", entity.id(), dialogueBoxData )
		end
	elseif entityType == "npc" then
		local settings = sb.jsonMerge(storage.settings, {
			voreType = storage.huntingTarget.voreType,
		})
		sbq.getRandomDialogue(".preyRequest", storage.huntingTarget.id, settings)

		sbq.addNamedRPC("sbqNPCGetConsent",
			world.sendEntityMessage(storage.huntingTarget.id, "sbqNPCGetConsent", entity.id(), storage.huntingTarget),
			function(result)
				if result == 1 then
					settings.willing = true
				end
				sbq.getRandomDialogue(dialogue.result.options[result][2], storage.huntingTarget.id, settings)
				if result == 2 then -- "No."
					sbq.getNextTarget()
				end
			end)
	elseif entityType == "monster" then
		sbq.forcePrey()
	end
end



function sbq.combatSwitchHuntingTarget(newTarget)
	if sbq.timer("combatSwitchHuntingTarget", 10) then
		sbq.searchForHealTarget(true)
		storage.huntingTarget = nil
		sbq.targetedEntities = {}
		sbq.addRPC(world.sendEntityMessage(newTarget, "sbqGetPreyEnabled"), function(preySettings)
			if (not preySettings) or (preySettings.preyEnabled == false) then return end
			local voreType = sbq.getCurrentVorePref("pred", preySettings, storage.settings.preferDigestHostiles and "digest" )
			if not voreType then return end
			local ext = sbq.getTargetExt(newTarget)
			local aggressive = world.entityAggressive(newTarget)
			local validTarget = false
			if aggressive and storage.settings[voreType .. "HuntHostile" .. ext] then
				validTarget = true
			end
			if not validTarget then return end
			storage.huntingTarget = {
				index = 1,
				id = newTarget,
				voreType = voreType,
				predOrPrey = "pred",
				combat = true,
			}
			self.board:setEntity("sbqHuntingTarget", newTarget)
		end)
	end
end

function sbq.searchForHealTarget(combat)
	if not storage.settings.preferHealFriendlies then return false end
	local entities = world.entityQuery(mcontroller.position(), 25, {
		withoutEntityId = entity.id(), includedTypes = {"creature"}
	})
	for i, newTarget in ipairs(entities) do
		if not world.entityAggressive(newTarget) then
			local health = world.entityHealth(newTarget)
			if health then
				local percent = health[1] / health[2]
				if percent < 0.25 then
					sbq.addRPC(world.sendEntityMessage(newTarget, "sbqGetPreyEnabled"), function(preySettings)
						if (not preySettings) or (preySettings.preyEnabled == false) then return end
						local voreType = sbq.getCurrentVorePref("pred", preySettings, storage.settings.preferHealFriendlies and "heal")
						if not voreType then return end
						local ext = sbq.getTargetExt(newTarget)
						local validTarget = false
						if storage.settings[voreType .. "HuntFriendly"..ext] then
							validTarget = true
						end
						if not validTarget then return end
						storage.huntingTarget = {
							index = 1,
							id = newTarget,
							voreType = voreType,
							predOrPrey = "pred",
							combat = combat,
						}
						self.board:setEntity("sbqHuntingTarget", newTarget)
					end)
				end
			end
		end
	end
end

function sbq.getTargetExt(target)
	local entityType = world.entityType(target)
	if entityType == "npc" then
		if world.callScriptedEntity(target, "config.getParameter", "isOC" ) then
			return "OCs"
		end
		if world.callScriptedEntity(target, "config.getParameter", "sbqNPC" ) then
			return "SBQNPCs"
		end
	elseif entityType == "player" then
		return "Players"
	end
	return "Other"
end

function sbq.combatEat()
	local settings = {
		voreType = storage.huntingTarget.voreType,
		voreResponse = "unprompted",
		location = sbq.predatorConfig.voreTypes[storage.huntingTarget.voreType],
		doingVore = "before"
	}
	sbq.requestTransition(storage.huntingTarget.voreType,
		{ id = storage.huntingTarget.id, hostile = world.entityAggressive(storage.huntingTarget.id) })
	self.board:setEntity("sbqHuntingTarget", nil)
	sbq.forceTimer("gotVored", delay or 1.5, function()
		if not storage.huntingTarget then return end
		settings.doingVore = "after"
		if sbq.checkOccupant(storage.huntingTarget.id) then
			sbq.getRandomDialogue(".vore", storage.huntingTarget.id, sb.jsonMerge(storage.settings, sb.jsonMerge(sbqPreyEnabled or {}, settings)))
			storage.huntingTarget = nil
			sbq.targetedEntities = {}
		end
	end)
end

function sbq.eatUnprompted()
	sbq.addNamedRPC("attemptingToEat", world.sendEntityMessage(storage.huntingTarget.id, "sbqGetPreyEnabled"), function(sbqPreyEnabled)
		if sbqPreyEnabled[storage.huntingTarget.voreType] and (sbqPreyEnabled.type ~= "prey")then
			local settings = {
				voreType = storage.huntingTarget.voreType,
				voreResponse = "unprompted",
				location = sbq.predatorConfig.voreTypes[storage.huntingTarget.voreType],
				doingVore = "before"
			}
			sbq.getRandomDialogue(".vore", storage.huntingTarget.id, sb.jsonMerge(storage.settings, sb.jsonMerge(sbqPreyEnabled or {}, settings)))
			local delay = dialogue.result.delay
			sbq.timer("eatMessage", delay or 1.5, function()
				if not storage.huntingTarget then sbq.getNextTarget() return end
				self.board:setEntity("sbqHuntingTarget", nil)
				sbq.requestTransition(storage.huntingTarget.voreType, { id = storage.huntingTarget.id })
				sbq.timer("gotVored", delay or 1.5, function()
					if not storage.huntingTarget then sbq.getNextTarget() return end
					settings.doingVore = "after"
					if sbq.checkOccupant(storage.huntingTarget.id) then
						sbq.getRandomDialogue(".vore", storage.huntingTarget.id, sb.jsonMerge(storage.settings, sb.jsonMerge(sbqPreyEnabled or {}, settings)))
						storage.huntingTarget = nil
						sbq.targetedEntities = {}
					else
						settings.voreResponse = "couldnt"
						sbq.getRandomDialogue(".vore", storage.huntingTarget.id, sb.jsonMerge(storage.settings, sb.jsonMerge(sbqPreyEnabled or {}, settings)))
						self.board:setEntity("sbqHuntingTarget", storage.huntingTarget.id)
					end
				end)
			end)
		else
			sbq.getNextTarget()
		end
	end)
end

function sbq.forcePrey()
	if not storage.huntingTarget then return end
	sbq.getRandomDialogue(".forcingPrey", storage.huntingTarget.id, storage.settings)
	sbq.timer("forcedPreyDialogue", dialogue.result.delay or 1.5, function ()
		world.sendEntityMessage(storage.huntingTarget.id, "requestTransition", storage.huntingTarget.voreType,
			{ id = entity.id(), willing = true })
		local id = storage.huntingTarget.id
		local voreType = storage.huntingTarget.voreType
		sbq.timer("forcedPreyCheckInside", 1, function ()
			if status.statusProperty("sbqType") == "prey" then
				storage.huntingTarget = nil
				sbq.targetedEntities = {}
				world.sendEntityMessage(id, "sbqSayRandomLine", entity.id(), {voreType = voreType}, ".unwillingPred")
			else
				sbq.getNextTarget()
			end
		end)
	end)
end

function sbq.getTarget()
	if npc.loungingIn() ~= nil and (status.statusProperty("sbqType") ~= "driver") then
		storage.huntingTarget = nil
		self.board:setEntity("sbqHuntingTarget", nil)
		sbq.targetedEntities = {}
		return
	end
	sbq.searchForHealTarget(false)
	if storage.huntingTarget and type(storage.huntingTarget.id) == "number" and world.entityExists(storage.huntingTarget.id) then
		if storage.persistentTarget and entity.entityInSight(storage.huntingTarget.id) then
			sbq.addRPC(world.sendEntityMessage(storage.huntingTarget.id, "sbqIsPreyEnabled", storage.huntingTarget.voreType), function (enabled)
				if enabled and enabled.enabled and enabled.type ~= "prey" and enabled.size
				and sbq.getSidedLocationWithSpace(sbq.predatorConfig.voreTypes[storage.huntingTarget.voreType], enabled.size)
				then
					self.board:setEntity("sbqHuntingTarget", storage.huntingTarget.id)
				else
					sbq.getNextTarget()
				end
			end)
			return
		end
		if math.random() > 0.5 then
			sbq.getNextTarget()
		end
	elseif storage.huntingTarget then
		sbq.getNextTarget()
	elseif (math.random() > 0.5) then
		local voreType, predOrPrey = sbq.getCurrentVorePref()
		if not voreType then return end
		local consent = sbq.huntingAskConsent(voreType, predOrPrey)
		if predOrPrey == "pred" then
			sbq.searchForValidPrey(voreType, consent)
		elseif predOrPrey == "prey" then
			sbq.searchForValidPred(voreType, consent)
		end
		sbq.timer("targeting", 1, function()
			table.sort(sbq.targetedEntities, function(a, b)
				return a[2] < b[2]
			end)
			if sbq.targetedEntities[1] then
				storage.huntingTarget = {
					index = 1,
					id = sbq.targetedEntities[1][1],
					voreType = voreType,
					predOrPrey = predOrPrey,
					getConsent = consent
				}
				self.board:setEntity("sbqHuntingTarget", sbq.targetedEntities[1][1])
			end
		end)
	end
end

function sbq.getNextTarget()
	if not sbq.targetedEntities then storage.huntingTarget = nil return end
	if storage.huntingTarget then
		storage.huntingTarget.index = storage.huntingTarget.index + 1
		storage.huntingTarget.id = (sbq.targetedEntities[storage.huntingTarget.index] or {})[1]
		if storage.huntingTarget.id then
			self.board:setEntity("sbqHuntingTarget", storage.huntingTarget.id)
		else
			storage.huntingTarget = nil
			self.board:setEntity("sbqHuntingTarget", nil)
		end
	end
end

function sbq.huntingAskConsent(voreType, predOrPrey)
	if storage.huntingTarget or (voreType and predOrPrey) then
		local consentVal
		if (predOrPrey or storage.huntingTarget.predOrPrey) == "pred" then
			consentVal = storage.settings[( voreType or storage.huntingTarget.voreType) .. "ConsentPred"] or 0.5
		elseif (predOrPrey or storage.huntingTarget.predOrPrey) == "prey" then
			consentVal = storage.settings[( voreType or storage.huntingTarget.voreType) .. "ConsentPrey"] or 0.5
		end
		if consentVal == 1 then return true end
		if consentVal == 0 then return false end
		return consentVal > math.random()
	end
end

function sbq.getFavoredVoreTypes(predOrPrey, preySettings, effectSlot)
	local favoredVoreTypes = {}
	for voreType, data in pairs(sbq.speciesConfig.sbqData.voreTypeData or {}) do
		if predOrPrey == "pred" and sbq.predatorSettings[voreType .. "Pred"]
			and (((sbq.speciesConfig.states or {})[sbq.state or "stand"] or {}).transitions or {})[voreType]
			and sbq.checkSettings((((sbq.speciesConfig.states or {})[sbq.state or "stand"] or {}).transitions or {})[voreType].settings, storage.settings)
		then
			local addType = true
			if preySettings then
				addType = preySettings[voreType]
			end
			if effectSlot then
				addType = false
				for i, location in ipairs(data.locations) do
					if storage.settings[location.."EffectSlot"] == effectSlot then
						addType = true break
					end
					if (effectSlot == "digest") and (storage.settings[location.."EffectSlot"] == "softDigest") and storage.settings.overrideSoftDigestForHostiles then
						addType = true break
					end
				end
			end
			if addType then
				for i = 1, (sbq.predatorSettings[voreType .. "PreferredPred"] or 5) do
					table.insert(favoredVoreTypes, voreType)
				end
			end
		elseif predOrPrey == "prey" and sbq.preySettings[voreType] then
			for i = 1, (sbq.predatorSettings[voreType .. "PreferredPrey"] or 5) do
				table.insert(favoredVoreTypes, voreType)
			end
		end
	end
	return favoredVoreTypes
end

sbq.satisfyInverse = {
	health = true,
	food = true,
	rest = true,
}

function sbq.getCurrentVorePref(predOrPrey, preySettings, healOrDigest)
	local predOrPrey = predOrPrey or sbq.getPredOrPrey()
	if not predOrPrey then return end
	local favoredVoreTypes = sbq.getFavoredVoreTypes(predOrPrey, preySettings, healOrDigest)
	if not favoredVoreTypes[1] then return end
	local favoredSelection = {
		{ favoredVoreTypes[math.random(#favoredVoreTypes)] },
		{ favoredVoreTypes[math.random(#favoredVoreTypes)] },
		{ favoredVoreTypes[math.random(#favoredVoreTypes)] },
		{ favoredVoreTypes[math.random(#favoredVoreTypes)] }
	}
	for i, selection in ipairs(favoredSelection) do
		local voreType = selection[1]
		local data = sbq.config.generalVoreTypeData[voreType] or {}
		local satisfyTable = {}
		if predOrPrey == "prey" then
			satisfyTable = data.satisfiesPrey
		elseif predOrPrey == "pred" then
			satisfyTable = data.satisfiesPred
		end
		for j, satisfy in ipairs(satisfyTable or {}) do
			if sbq.satisfyInverse[satisfy] then
				favoredSelection[i][2] = (favoredSelection[i][2] or 0) + (1 - status.resourcePercentage(satisfy))
			else
				favoredSelection[i][2] = (favoredSelection[i][2] or 0) + (status.resourcePercentage(satisfy))
			end
		end
	end
	table.sort(favoredSelection, function (a, b)
		return a[2] > b[2]
	end)

	return favoredSelection[1][1], predOrPrey
end

local negative = { 1, -1 }
local function getPositiveNegativeFloat()
	return math.random() * negative[math.random(#negative)]
end

function sbq.getPredOrPrey()
	local bias = 0
	if storage.isHungry ~= false then
		bias = bias + ((1 - status.resourcePercentage("food")) * 0.5)
	end
	if storage.isSleepy ~= false then
		bias = bias + ((1 - status.resourcePercentage("sbqRest")) * 0.5)
	end
	local result = math.max(sbq.predatorSettings.predPreyLeanMin or -1, math.min(sbq.predatorSettings.predPreyLeanMax or 1, (bias or 0) + sbq.getClosestValue(sbq.predatorSettings.predPreyLean or 0, {
		getPositiveNegativeFloat(),
		getPositiveNegativeFloat(),
		getPositiveNegativeFloat(),
		getPositiveNegativeFloat(),
		getPositiveNegativeFloat()
	})))

	if (result >= 0) and (sbq.occupants.total or 0) < 8 then return "pred" end
	if result < 0 then return "prey" end
end

function sbq.searchForValidPrey(voreType, consent)
	sbq.targetedEntities = {
	}

	if storage.settings[voreType.."HuntFriendlyPlayers"] or storage.settings[voreType.."HuntHostilePlayers"] then
		local entities = world.playerQuery(mcontroller.position(), 50)
		for i, eid in ipairs(entities) do
			sbq.maybeAddPreyToTargetList(eid, voreType, "Players", 1.9)
		end
	end
	if storage.settings[voreType.."HuntFriendlyOCs"] or storage.settings[voreType.."HuntHostileOCs"] then
		local entities = world.npcQuery(mcontroller.position(), 50, { withoutEntityId = entity.id(), callScript = "config.getParameter", callScriptArgs = { "isOC" } })
		for i, eid in ipairs(entities) do
			sbq.maybeAddPreyToTargetList(eid, voreType, "OCs", 2)
		end
	end
	if storage.settings[voreType.."HuntFriendlySBQNPCs"] or storage.settings[voreType.."HuntHostileSBQNPCs"] then
		local entities = world.npcQuery(mcontroller.position(), 50, { withoutEntityId = entity.id(), callScript = "config.getParameter", callScriptArgs = { "sbqNPC" } })
		for i, eid in ipairs(entities) do
			if not world.callScriptedEntity(eid, "config.getParameter", "isOC") then
				sbq.maybeAddPreyToTargetList(eid, voreType, "SBQNPCs", 2.1)
			end
		end
	end
	if storage.settings[voreType.."HuntFriendlyOther"] or storage.settings[voreType.."HuntHostileOther"] then
		local entities = world.npcQuery(mcontroller.position(), 50, { withoutEntityId = entity.id(), callScript = "config.getParameter", callScriptArgs = { "sbqNPC" }, callScriptResult = false })
		util.appendLists(entities, world.monsterQuery(mcontroller.position(), 50))
		for i, eid in ipairs(entities) do
			sbq.maybeAddPreyToTargetList(eid, voreType, "Other", 3)
		end
	end
end

function sbq.maybeAddPreyToTargetList(eid, voreType, ext, score)
	local aggressive = world.entityAggressive(eid)
	local validTarget = false
	if aggressive and storage.settings[voreType .. "HuntHostile" .. ext] then
		validTarget = true
	elseif not aggressive and storage.settings[voreType .. "HuntFriendly"..ext] then
		validTarget = true
	end
	if sbq.checkOccupant(eid) then
		validTarget = false
	end
	if validTarget then
		sbq.addRPC(world.sendEntityMessage(eid, "sbqIsPreyEnabled", voreType), function (enabled)
			if enabled and enabled.enabled and enabled.type ~= "prey" and enabled.size then
				local scale = (status.statusProperty("sbqScale") or 1)
				local relativeSize = enabled.size / scale
				local location = ((((sbq.speciesConfig.states or {})[sbq.state or "stand"] or {}).transitions or {})[voreType] or {}).location
				if (relativeSize > (storage.settings[voreType .. "PreferredPreySizeMin"] or 0.1))
				and (relativeSize < (storage.settings[voreType .. "PreferredPreySizeMax"] or 1.25))
				and location and sbq.getSidedLocationWithSpace(location, enabled.size)
				then
					table.insert(sbq.targetedEntities, {eid, score * ((math.abs((storage.settings[voreType .. "PreferredPreySize"] or 0.5)-relativeSize) * 5) + world.magnitude(mcontroller.position(), world.entityPosition(eid)))})
				end
			end
		end)
	end
end

function sbq.searchForValidPred(voreType, consent)
	sbq.targetedEntities = {
	}

	if storage.settings[voreType.."BaitFriendlyPlayers"] or storage.settings[voreType.."BaitHostilePlayers"] then
		local entities = world.playerQuery(mcontroller.position(), 50)
		for i, eid in ipairs(entities) do
			sbq.maybeAddPredToTargetList(eid, voreType, "Players", 1.9, consent)
		end
	end
	if storage.settings[voreType.."BaitFriendlyOCs"] or storage.settings[voreType.."BaitHostileOCs"] then
		local entities = world.npcQuery(mcontroller.position(), 50, { withoutEntityId = entity.id(), callScript = "config.getParameter", callScriptArgs = { "isOC" } })
		for i, eid in ipairs(entities) do
			sbq.maybeAddPredToTargetList(eid, voreType, "OCs", 2)
		end
	end
	if storage.settings[voreType.."BaitFriendlySBQNPCs"] or storage.settings[voreType.."BaitHostileSBQNPCs"] then
		local entities = world.npcQuery(mcontroller.position(), 50, { withoutEntityId = entity.id(), callScript = "config.getParameter", callScriptArgs = { "sbqNPC" } })
		for i, eid in ipairs(entities) do
			if not world.callScriptedEntity(eid, "config.getParameter", "isOC") then
				sbq.maybeAddPredToTargetList(eid, voreType, "SBQNPCs", 2.1)
			end
		end
	end
	if storage.settings[voreType.."BaitFriendlyOther"] or storage.settings[voreType.."BaitHostileOther"] then
		local entities = world.npcQuery(mcontroller.position(), 50, { withoutEntityId = entity.id(), callScript = "config.getParameter", callScriptArgs = { "sbqNPC" }, callScriptResult = false })
		util.appendLists(entities, world.monsterQuery(mcontroller.position(), 50))
		for i, eid in ipairs(entities) do
			sbq.maybeAddPredToTargetList(eid, voreType, "Other", 3)
		end
	end
end

function sbq.maybeAddPredToTargetList(eid, voreType, ext, score, consent)
	local aggressive = world.entityAggressive(eid)
	local validTarget = false
	if aggressive and storage.settings[voreType .. "BaitHostile" .. ext] then
		validTarget = true
	elseif not aggressive and storage.settings[voreType .. "BaitFriendly"..ext] then
		validTarget = true
	end
	if sbq.checkOccupant(eid) then
		validTarget = false
	end
	if validTarget then
		sbq.addRPC(world.sendEntityMessage(eid, "sbqIsPredEnabled", voreType), function(enabled)
			if enabled and enabled.enabled and enabled.type ~= "prey" and enabled.size and (consent or enabled.unwilling) then
				sbq.addRPC(world.sendEntityMessage(eid, "sbqCheckAssociatedEffects", voreType), function(effects)
					if effects then
						local badEffect = false
						local effectScore = 0
						for i, effect in ipairs(effects) do
							if (effect == "none" and storage.settings[voreType .. "PreyDislikesNone"])
								or (effect == "heal" and storage.settings[voreType .. "PreyDislikesHeal"])
								or (effect == "digest" and storage.settings[voreType .. "PreyDislikesDigest"])
								or (effect == "softDigest" and storage.settings[voreType .. "PreyDislikesSoftDigest"])
							then
								badEffect = true
								break
							elseif (effect == "none" and storage.settings[voreType .. "PreyPrefersNone"])
								or (effect == "heal" and storage.settings[voreType .. "PreyPrefersHeal"])
								or (effect == "digest" and storage.settings[voreType .. "PreyPrefersDigest"])
								or (effect == "softDigest" and storage.settings[voreType .. "PreyPrefersSoftDigest"])
							then
								effectScore = effectScore + (10/#effects)
							end
						end
						local scale = (status.statusProperty("sbqScale") or 1)
						local relativeSize = enabled.size / scale
						if not badEffect
						and (relativeSize > (storage.settings[voreType .. "PreferredPredSizeMin"] or 0.75))
						and (relativeSize < (storage.settings[voreType .. "PreferredPredSizeMax"] or 3))
						then
							table.insert(sbq.targetedEntities, { eid, score * (
								(math.abs((storage.settings[voreType .. "PreferredPredSize"] or 2) - relativeSize) * 5)
									+ world.magnitude(mcontroller.position(), world.entityPosition(eid))
									- effectScore
							)})
						end
					end
				end)
			end
		end)
	end
end
