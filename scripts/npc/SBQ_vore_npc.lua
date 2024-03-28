
local old = {
	init = init,
	update = update,
	uninit = uninit,
}

dialogueStepScripts = {}

-- require"/interface/scripted/sbq/DialogueBox/sbqdialogueStepScripts.lua"
-- require"/interface/scripted/sbq/settings/autoSetSettings.lua"
-- require"/interface/scripted/sbq/DialogueBox/scripts/npc.lua"

require"/scripts/actor/SBQ_actor.lua"
require"/scripts/any/SBQ_rewards.lua"
require"/scripts/any/SBQ_vore_main.lua"
require"/scripts/any/SBQ_dialogue.lua"
require"/scripts/any/SBQ_dialogue_scripts.lua"

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

	message.setHandler("sbqSwapFollowing", function(_, _)
		if storage.behaviorFollowing then
			if world.getProperty("ephemeral") then
				_ENV.recruitable.confirmUnfollowBehavior()
				return { "None", {} }
			else
				return _ENV.recruitable.generateUnfollowInteractAction()
			end
		else
			return _ENV.recruitable.generateFollowInteractAction()
		end
	end)
	message.setHandler("recruit.confirmFollow", function(_,_)
		_ENV.recruitable.confirmFollow(true)
	end)
	message.setHandler("recruit.confirmUnfollow", function(_,_)
		_ENV.recruitable.confirmUnfollow(true)
	end)
	message.setHandler("recruit.confirmUnfollowBehavior", function(_,_)
		_ENV.recruitable.confirmUnfollowBehavior(true)
	end)
end

function update(dt)
	old.update(dt)
	sbq.update(dt)
end

function uninit()
	old.uninit()
end

function interact(args)
	if _ENV.recruitable.isRecruitable() then
		return _ENV.recruitable.generateRecruitInteractAction()
	end
	_ENV.setInteracted(args)

	if sbq.settings.interactDialogue then
		local dialogueBoxData = sb.jsonMerge(sbq.getSettingsPageData(), {
			dialogueTree = sbq.dialogueTree
		})
		if npc.loungingIn() == args.sourceId then
			dialogueBoxData.dialogueTreeStart = ".predInteract"
			dialogueBoxData.noActions = true
			-- return { "Message", { messageType = "sbqPredHudPreyDialogue", messageArgs = {
			-- 	entity.id(),
			--     "The quick brown fox jumped over the lazy dog.",
			-- }}}
		elseif Occupants.entityId[tostring(args.sourceId)] then
			dialogueBoxData.dialogueTreeStart = ".occupantInteract"
		end
		return {"ScriptPane", { data = {sbq = dialogueBoxData}, gui = { }, scripts = {"/metagui/sbq/build.lua"}, ui = "starbecue:dialogueBox" }, entity.id()}
	else
		if npc.loungingIn() == args.sourceId then return end

		local results = { SpeciesScript:interact(args) }
		if results[2] == "interactAction" then
			return results[3]
		end
	end
end

local _equipped_primary = equipped.primary
function equipped.primary(itemDescriptor)
	if not itemDescriptor then
		npc.setItemSlot("primary", "sbqControllerNPC")
	else
		return _equipped_primary(itemDescriptor)
	end
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
