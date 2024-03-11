
local old = {
    init = init,
    update = update,
    uninit = uninit,

    preservedStorage = preservedStorage,
}

dialogueBoxScripts = {}

-- require"/interface/scripted/sbq/DialogueBox/sbqDialogueBoxScripts.lua"
-- require"/interface/scripted/sbq/settings/autoSetSettings.lua"
-- require"/interface/scripted/sbq/DialogueBox/scripts/npc.lua"

require"/scripts/actor/SBQ_actor.lua"
require"/scripts/any/SBQ_rewards.lua"
require"/scripts/any/SBQ_vore_main.lua"

function init()
	sbq.config = root.assetJson("/sbq.config")
    sbq.npcConfig = root.npcConfig(npc.npcType())
	storage = storage or {}
	storage.sbqUpgrades = storage.sbqUpgrades or {}
    if not storage.sbqUpgrades.candiesEaten then
        storage.sbqUpgrades.candiesEaten = {}
		for i = 1, math.max(npc.level(), 1) do
			storage.sbqUpgrades.candiesEaten[i] = 1
		end
	end
    old.init()
	sbq.init()

	if not self.uniqueId then
		self.uniqueId = sb.makeUuid()
		_ENV.updateUniqueId()
	end

	-- for _, script in ipairs(sbq.dialogueBoxScripts or {}) do
	-- 	require(script)
	-- end

	-- message.setHandler("sbqSetInteracted", function (_,_, id)
	-- 	self.interacted = true
	-- 	self.board:setEntity("interactionSource", id)
    -- end)

	-- message.setHandler("sbqSwapFollowing", function(_, _)
	-- 	if storage.behaviorFollowing then
	-- 		if world.getProperty("ephemeral") then
	-- 			recruitable.confirmUnfollowBehavior()
	-- 			return { "None", {} }
	-- 		else
	-- 			return recruitable.generateUnfollowInteractAction()
	-- 		end
	-- 	else
	-- 		return recruitable.generateFollowInteractAction()
	-- 	end
	-- end)
	-- message.setHandler("recruit.confirmFollow", function(_,_)
	-- 	recruitable.confirmFollow(true)
	-- end)
	-- message.setHandler("recruit.confirmUnfollow", function(_,_)
	-- 	recruitable.confirmUnfollow(true)
	-- end)
	-- message.setHandler("recruit.confirmUnfollowBehavior", function(_,_)
	-- 	recruitable.confirmUnfollowBehavior(true)
    -- end)
end

function update(dt)
    old.update(dt)
	sbq.update(dt)
end

function uninit()
	old.uninit()
end

function interact(args)
	if npc.loungingIn() == args.sourceId then
        sbq.say("-TODO Re-Implement Dialogue")
		return
	end
	if true then -- TODO make this a check between whether dialogue is enabled on the NPC or not
		local results = { Transformation:interact(args) }
		if results[2] == "interactAction" then
			return results[3]
		end
	end

	-- if recruitable.isRecruitable() then
	-- 	return recruitable.generateRecruitInteractAction()
	-- end
	-- setInteracted(args)


	-- local dialogueBoxData = sbq.getDialogueBoxData()

	-- if status.statusProperty("sbqType") == "prey" then
	-- 	if args.predData then
	-- 		sbq.predData = args.predData
	-- 		local settings = args.predData.settings
	-- 		settings.location = args.predData.location
	-- 		settings.predator = args.predData.predator
	-- 		settings.isPrey = true

	-- 		settings.personality = storage.settings.personality
	-- 		settings.mood = storage.settings.mood

	-- 		dialogueBoxData.settings = sb.jsonMerge(dialogueBoxData.settings, settings)
	-- 		dialogueBoxData.dialogueTreeStart = ".struggling"
	-- 		if args.predData.infused then
	-- 			dialogueBoxData.dialogueTreeStart = ".infused"
	-- 		end
	-- 		return {"ScriptPane", { data = dialogueBoxData, gui = { }, scripts = {"/metagui/sbq/build.lua"}, ui = "starbecue:dialogueBox" }}
	-- 	else
	-- 		return
	-- 	end
	-- else
	-- 	local location = sbq.getOccupantArg(args.sourceId, "location")
	-- 	if location ~= nil then
	-- 		local flags = sbq.getOccupantArg(args.sourceId, "flags") or {}
	-- 		dialogueBoxData.dialogueTreeStart = ".struggle"
	-- 		dialogueBoxData.settings.location = location
	-- 		dialogueBoxData.settings.playerPrey = true
	-- 		if flags.infused then
	-- 			dialogueBoxData.settings.predator = npc.species()
	-- 			dialogueBoxData.dialogueTreeStart = ".infusedTease"
	-- 		end
	-- 	end
	-- 	return {"ScriptPane", { data = dialogueBoxData, gui = { }, scripts = {"/metagui/sbq/build.lua"}, ui = "starbecue:dialogueBox" }}
	-- end
end

function preservedStorage()
    return sb.jsonMerge(old.preservedStorage(), {
		settings = storage.settings
	})
end

-- I fucking hate starbound
-- function recruitable.generateRecruitInfo()
-- 	local rank = config.getParameter("crew.rank") or storage.recruitRank or recruitable.generateRank()
-- 	local parameters = {
-- 		level = npc.level(),
-- 		identity = npc.humanoidIdentity(),
-- 		scriptConfig = {
-- 			personality = personality(),
-- 			crew = {
-- 				rank = rank
-- 			},
--             initialStorage = preservedStorage(),
-- 			sbqSettings = storage.settings,
-- 			uniqueId = config.getParameter("preservedUuid") or config.getParameter("uniqueId") or entity.uniqueId(),
-- 			preservedUuid = config.getParameter("preservedUuid") or config.getParameter("uniqueId") or
-- 			entity.uniqueId()
-- 		},
-- 		statusControllerSettings = {
-- 			statusProperties = {
-- 				sbqPreyEnabled = status.statusProperty("sbqPreyEnabled"),
-- 				sbqStoredDigestedPrey = status.statusProperty("sbqStoredDigestedPrey"),
--                 sbqCumulativeData = status.statusProperty("sbqCumulativeData"),
-- 				speciesAnimOverrideSettings = status.statusProperty("speciesAnimOverrideSettings")
-- 			}
-- 		}
-- 	}
-- 	local poly = mcontroller.collisionPoly()
-- 	if #poly <= 0 then poly = nil end

-- 	local name = world.entityName(entity.id())

-- 	if not entity.uniqueId() then
-- 	  world.setUniqueId(entity.id(), sb.makeUuid())
-- 	end

-- 	storage.statusText = storage.statusText or randomStatusText(personalityType())

-- 	return {
-- 		name = name,
-- 		uniqueId = entity.uniqueId(),
-- 		portrait = world.entityPortrait(entity.id(), "full"),
-- 		collisionPoly = poly,
-- 		statusText = storage.statusText,
-- 		rank = rank,
-- 		uniform = storage.crewUniform,
-- 		status = getCurrentStatus(),
-- 		storage = preservedStorage(),
-- 		config = {
-- 			species = npc.species(),
-- 			type = npc.npcType(),
-- 			seed = npc.seed(),
-- 			parameters = parameters
-- 		}
-- 	}
-- end
