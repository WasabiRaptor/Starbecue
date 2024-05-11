
local old = {
	init = init,
	update = update,
	uninit = uninit,
	tenant_setHome = tenant.setHome,
	equipped_primary = equipped.primary,
	participateInNewQuests = _ENV.participateInNewQuests,
}

dialogueStepScripts = {}
require"/scripts/actor/SBQ_actor.lua"
require"/scripts/any/SBQ_rewards.lua"
require"/scripts/any/SBQ_vore_main.lua"
require"/scripts/any/SBQ_dialogue.lua"
require"/scripts/any/SBQ_dialogue_scripts.lua"
require"/scripts/actor/SBQ_hunting.lua"
function sbq.setupPublicSettings() -- this is just to make it not setup the settings twice
end
function init()
	sbq.config = root.assetJson("/sbq.config")
	sbq.pronouns = root.assetJson("/sbqPronouns.config")

	storage = storage or {}
	storage.sbqSettings = sb.jsonMerge(config.getParameter("sbqSettings") or {}, storage.sbqSettings or {})
	storage.sbqUpgrades = sb.jsonMerge(config.getParameter("sbqUpgrades") or {}, storage.sbqUpgrades or {})
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
	for _, script in ipairs(sbq.dialogueTree.dialogueStepScripts or {}) do
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
	sbq.randomTimer("huntingCycle", 60, 5*60) -- to just, start the timer randomly so every NPC isn't hunting immediately
end

function update(dt)
	old.update(dt)
	sbq.update(dt)
	if sbq.randomTimer("huntingCycle", 5*60, 10*60) then
		sbq_hunting.start()
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

function participateInNewQuests()
	return sbq.settings.questParticipation and old.participateInNewQuests()
end
