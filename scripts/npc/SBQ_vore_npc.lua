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
	die = die,
	tenant_setHome = tenant.setHome,
	equipped_primary = equipped.primary,
	tenant_graduate = tenant.graduate,
	participateInNewQuests = _ENV.participateInNewQuests,
	setNpcItemSlot = _ENV.setNpcItemSlot
}

function sbq.setupPublicSettings() -- this is just to make it not setup the settings twice
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
	old.init()
	sbq.config = root.assetJson("/sbq.config")
	sbq.pronouns = root.assetJson("/sbqPronouns.config")

	storage.sbqSettings = storage.sbqSettings or config.getParameter("sbqSettings")
	storage.sbqUpgrades = storage.sbqUpgrades or config.getParameter("sbqUpgrades") or {}
	math.randomseed(npc.seed())
	sbq.randomizeSettings()

	if not storage.sbqUpgrades.candiesEaten then
		storage.sbqUpgrades.candiesEaten = {}
		for i = 1, math.floor(math.max(npc.level(), 1)) do
			storage.sbqUpgrades.candiesEaten[i] = 1
		end
		local digestPower = math.max(1, (npc.level() + 1) / 2)
		storage.sbqSettings.acidDigestPower = storage.sbqSettings.acidDigestPower or digestPower
		storage.sbqSettings.cumDigestPower = storage.sbqSettings.cumDigestPower or digestPower
		storage.sbqSettings.femcumDigestPower = storage.sbqSettings.femcumDigestPower or digestPower
		storage.sbqSettings.milkDigestPower = storage.sbqSettings.milkDigestPower or digestPower
		storage.sbqSettings.escapeDifficulty = storage.sbqSettings.escapeDifficulty or digestPower

	end
	if not self.uniqueId then
		self.uniqueId = sb.makeUuid()
		_ENV.updateUniqueId()
	end

	if npc.getHumanoidParameter("sbqEnabled") then
		sbq.init({root.speciesConfig(sbq.species()).voreConfig or "/humanoid/any/vore.config", config.getParameter("voreConfig")})
	else
		npc.setHumanoidParameter("sbqEnabled", true)
		npc.refreshHumanoidParameters()
	end

	sbq.dialogueTree = sbq.fetchConfigArray(config.getParameter("dialogueTree"))
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

	message.setHandler("sbqUpdateIdentities", function (_,_, response)
		status.setStatusProperty("sbqSpeciesIdentities", response.speciesIdentites)
		npc.setHumanoidIdentity(response.currentIdentity)
		local parent, recruitUuid = sbq.parentEntity()
		if parent then
			world.sendEntityMessage(parent, "sbqParentUpdateIdentities", recruitUuid, entity.uniqueId(), response)
		end
	end)

	if not status.statusProperty("sbqSpeciesIdentities") then
		status.setStatusProperty("sbqSpeciesIdentities", {[npc.species()] = npc.humanoidIdentity()})
	end

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
	if sbq.randomTimer(
		"sendDeeperCycle",
		(sbq.voreConfig.sendDeeperCycleMin or sbq.config.sendDeeperCycleMin) * 60,
		(sbq.voreConfig.sendDeeperCycleMax or sbq.config.sendDeeperCycleMax) * 60
	) then
		sbq.queueAction("sendDeeper", Occupants.randomActiveOccupant())
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

function die()
	for i, occupant in ipairs(Occupants.list) do
		occupant:remove("died")
	end
	old.die()
end
