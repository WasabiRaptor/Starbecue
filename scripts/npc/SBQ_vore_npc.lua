dialogueStepScripts = {}
require"/scripts/actor/SBQ_actor.lua"
require"/scripts/any/SBQ_rewards.lua"
require"/scripts/any/SBQ_vore_main.lua"
require"/scripts/any/SBQ_dialogue.lua"
require"/scripts/any/SBQ_dialogue_scripts.lua"
require"/scripts/actor/SBQ_hunting.lua"

local old = {
	init = init,
	update = update,
	uninit = uninit,
	tenant_setHome = tenant.setHome,
	equipped_primary = equipped.primary,
	tenant_graduate = tenant.graduate,
	participateInNewQuests = _ENV.participateInNewQuests,
	sbq_getSettingsPageData = sbq.getSettingsPageData,
	setNpcItemSlot = _ENV.setNpcItemSlot
}

function sbq.setupPublicSettings() -- this is just to make it not setup the settings twice
end
function sbq.getSettingsPageData()
	local settingsPageData = old.sbq_getSettingsPageData()
	settingsPageData.cosmeticSlots = {
		headCosmetic = humanoid.getItemSlot("headCosmetic"),
		chestCosmetic = humanoid.getItemSlot("chestCosmetic"),
		legsCosmetic = humanoid.getItemSlot("legsCosmetic"),
		backCosmetic = humanoid.getItemSlot("backCosmetic"),
	}
	return settingsPageData
end
function _ENV.recruitable.setUniform()
	-- we don't want them overriding the cosmetics we give them
end
function setNpcItemSlot(...)
	old.setNpcItemSlot(...)
	self.sheathedPrimary2 = nil
	self.sheathedAlt2 = nil
end

function init()
	sbq.config = root.assetJson("/sbq.config")
	sbq.pronouns = root.assetJson("/sbqPronouns.config")

	storage = storage or {}
	storage.sbqSettings = storage.sbqSettings or config.getParameter("sbqSettings")
	storage.sbqUpgrades = storage.sbqUpgrades or config.getParameter("sbqUpgrades") or {}
	local randomizeSettings = config.getParameter("sbqRandomizeSettings")
	math.randomseed(npc.seed())
	if randomizeSettings and not storage.sbqSettings then
		randomizeSettings = root.fetchConfigArray(randomizeSettings)
		storage.sbqSettings = {}
		for k, v in pairs(randomizeSettings) do
			if sbq.config.groupedSettings[k] then
				storage.sbqSettings[k] = {}
				for g, settings in pairs(v) do
					storage.sbqSettings[k][g] = {}
					for setting, v in pairs(settings) do
						if type(v) == "table" then storage.sbqSettings[k][g][setting] = v[math.random(#v)] end
					end
				end
			else
				if type(v) == "table" then storage.sbqSettings[k] = v[math.random(#v)] end
			end
		end
		-- copy values from other randomized settings
		for k, v in pairs(randomizeSettings) do
			if sbq.config.groupedSettings[k] then
				for g, settings in pairs(v) do
					for setting, v in pairs(settings) do
						if type(v) == "string" then
							if v:sub(1,1) == "." then
								storage.sbqSettings[k][g][setting] = sbq.queryPath(storage.sbqSettings, v:sub(2,-1))
							else
								storage.sbqSettings[k][g][setting] = storage.sbqSettings[k][g][v]
							end
						end
					end
				end
			else
				if type(v) == "string" then
					if v:sub(1, 1) == "." then
						storage.sbqSettings[k] = sbq.queryPath(storage.sbqSettings, v:sub(2,-1))
					else
						storage.sbqSettings[k] = storage.sbqSettings[v]
					end
				end
			end
		end
	end
	math.randomseed(npc.seed())

	if not storage.sbqUpgrades.candiesEaten then
		storage.sbqUpgrades.candiesEaten = {}
		for i = 1, math.max(npc.level(), 1) do
			storage.sbqUpgrades.candiesEaten[i] = 1
		end
	end
	old.init()
	if not self.uniqueId then
		self.uniqueId = sb.makeUuid()
		_ENV.updateUniqueId()
	end

	sbq.init({root.speciesConfig(humanoid.species()).voreConfig or "/humanoid/any/vore.config", config.getParameter("voreConfig")})
	sbq.dialogueTree = root.fetchConfigArray(config.getParameter("dialogueTree"))
	for _, script in ipairs((sbq.dialogueTree or {}).dialogueStepScripts or {}) do
		require(script)
	end
	message.setHandler("sbqSetInteracted", function (_,_, id)
		self.interacted = true
		self.board:setEntity("interactionSource", id)
	end)

	message.setHandler("sbqRecruitFollow", function (_,_)
		world.sendEntityMessage(_ENV.recruitable.ownerUuid(), "recruits.requestFollow", entity.uniqueId(), _ENV.recruitable.recruitUuid(), _ENV.recruitable.generateRecruitInfo())
	end)

	message.setHandler("sbqRecruitUnfollow", function (_,_)
		if world.getProperty("ephemeral") then
			_ENV.recruitable.confirmUnfollowBehavior()
		else
			world.sendEntityMessage(_ENV.recruitable.ownerUuid(), "recruits.requestUnfollow", entity.uniqueId(), _ENV.recruitable.recruitUuid())
		end
	end)

	message.setHandler("sbqPromptResponse", function (_,_,...)
		sbq_hunting.promptResponse({...})
	end)
	message.setHandler("sbqUpdateCosmeticSlot", function(_, _, slot, item)
		setNpcItemSlot(slot, item)
		tenant.backup()
	end)

	sbq.randomTimer("huntingCycle", 60, 5 * 60) -- to just, start the timer randomly so every NPC isn't hunting immediately
	sbq.randomTimer("lockDownCycle", 60, 5 * 60) -- to just, start the timer randomly so every NPC isn't hunting immediately
end

function update(dt)
	old.update(dt)
	sbq.update(dt)
	if sbq.randomTimer(
		"huntingCycle",
		(sbq.voreConfig.huntingCycleMin or sbq.config.huntingCycleMin) * 60,
		(sbq.voreConfig.huntingCycleMax or sbq.config.huntingCycleMax) * 60
	) then
		sbq_hunting.start()
	end
	if sbq.randomTimer(
		"lockDownCycle",
		(sbq.voreConfig.lockDownCycleMin or sbq.config.lockDownCycleMin) * 60,
		(sbq.voreConfig.lockDownCycleMax or sbq.config.lockDownCycleMax) * 60
	) then
		if Occupants.checkActiveOccupants() then
			if status.statPositive("sbqLockDown") then
				if (math.random() < (sbq.voreConfig.lockDownClearChance or sbq.config.lockDownClearChance)) then
					sbq.queueAction("lockDownClear", Occupants.randomActiveOccupant())
				end
			elseif (math.random() < (sbq.settings.lockDownChance)) then
				sbq.queueAction("lockDown", Occupants.randomActiveOccupant())
			end
		end
	end
end

function uninit()
	old.uninit()
end

function interact(args)
	if _ENV.recruitable.isRecruitable() then
		return _ENV.recruitable.generateRecruitInteractAction()
	end
	_ENV.setInteracted(args)
	local prompted = sbq_hunting.prompted[args.sourceId]
	if prompted then
		return prompted
	end
	return SpeciesScript:interact(args)
end

function equipped.primary(itemDescriptor)
	if not itemDescriptor then
		npc.setItemSlot("primary", "sbqControllerNPC")
	else
		return old.equipped_primary(itemDescriptor)
	end
end

function tenant.setHome(...)
	old.tenant_setHome(...)
	local parent, recruitUuid = sbq.parentEntity()
	if parent then
		world.sendEntityMessage(parent, "sbqParentImportSettings", recruitUuid, entity.uniqueId(), sbq.getSettingsOf.all())
	end
end

function tenant.graduate()
	if not sbq.settings.npcGraduation then return end
	old.tenant_graduate()
end

function participateInNewQuests()
	return sbq.settings.questParticipation and old.participateInNewQuests()
end
