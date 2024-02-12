
local old = {
    init = init,
    update = update,
    uninit = uninit,

    preservedStorage = preservedStorage,
}

sbq.currentData = {}
sbq.dialogueBoxOpen = 0
sbq.targetedEntities = {}
sbq.queuedTransitions = {}

dialogueBoxScripts = {}

require"/interface/scripted/sbq/sbqDialogueBox/sbqDialogueBoxScripts.lua"
require"/interface/scripted/sbq/sbqSettings/autoSetSettings.lua"
require"/interface/scripted/sbq/sbqDialogueBox/scripts/npc.lua"

require"/scripts/any/SBQ_rewards.lua"
require"/scripts/any/SBQ_vore_main.lua"

function init()
	sbq.config = root.assetJson("/sbq.config")
	sbq.npcConfig = root.npcConfig(npc.npcType())

	old.init()

	if not self.uniqueId then
		self.uniqueId = sb.makeUuid()
---@diagnostic disable-next-line: undefined-global
		updateUniqueId()
	end

	sbq.dialogueTree = config.getParameter("dialogueTree")
	sbq.dialogueBoxScripts = config.getParameter("dialogueBoxScripts")

	storage.isHorny = config.getParameter("isHorny")
	storage.isHungry = config.getParameter("isHungry")
	storage.isHungry = config.getParameter("isSleepy")
	storage.persistentTarget = config.getParameter("persistentTarget")

	for _, script in ipairs(sbq.dialogueBoxScripts or {}) do
		require(script)
	end

	message.setHandler("sbqSay", function (_,_, string, tags, imagePortrait, emote, appendName)
		sbq.say(string, tags, imagePortrait, emote, appendName)
	end)
	message.setHandler("sbqSetInteracted", function (_,_, id)
		self.interacted = true
		self.board:setEntity("interactionSource", id)
	end)
	message.setHandler("sbqSwapFollowing", function(_, _)
		if storage.behaviorFollowing then
			if world.getProperty("ephemeral") then
				recruitable.confirmUnfollowBehavior()
				return { "None", {} }
			else
				return recruitable.generateUnfollowInteractAction()
			end
		else
			return recruitable.generateFollowInteractAction()
		end
	end)
	message.setHandler("recruit.confirmFollow", function(_,_)
		recruitable.confirmFollow(true)
	end)
	message.setHandler("recruit.confirmUnfollow", function(_,_)
		recruitable.confirmUnfollow(true)
	end)
	message.setHandler("recruit.confirmUnfollowBehavior", function(_,_)
		recruitable.confirmUnfollowBehavior(true)
    end)

end

function update(dt)
	sbq.dialogueBoxOpen = math.max(0, sbq.dialogueBoxOpen - dt)

	sbq.passiveStatChanges(dt)

	old.update(dt)
end

function uninit()
	old.uninit()
end

function interact(args)
	if recruitable.isRecruitable() then
		return recruitable.generateRecruitInteractAction()
	end
	setInteracted(args)

	local dialogueBoxData = sbq.getDialogueBoxData()

	if status.statusProperty("sbqType") == "prey" then
		if args.predData then
			sbq.predData = args.predData
			local settings = args.predData.settings
			settings.location = args.predData.location
			settings.predator = args.predData.predator
			settings.isPrey = true

			settings.personality = storage.settings.personality
			settings.mood = storage.settings.mood

			dialogueBoxData.settings = sb.jsonMerge(dialogueBoxData.settings, settings)
			dialogueBoxData.dialogueTreeStart = ".struggling"
			if args.predData.infused then
				dialogueBoxData.dialogueTreeStart = ".infused"
			end
			return {"ScriptPane", { data = dialogueBoxData, gui = { }, scripts = {"/metagui/sbq/build.lua"}, ui = "starbecue:dialogueBox" }}
		else
			return
		end
	else
		local location = sbq.getOccupantArg(args.sourceId, "location")
		if location ~= nil then
			local flags = sbq.getOccupantArg(args.sourceId, "flags") or {}
			dialogueBoxData.dialogueTreeStart = ".struggle"
			dialogueBoxData.settings.location = location
			dialogueBoxData.settings.playerPrey = true
			if flags.infused then
				dialogueBoxData.settings.predator = npc.species()
				dialogueBoxData.dialogueTreeStart = ".infusedTease"
			end
		end
		return {"ScriptPane", { data = dialogueBoxData, gui = { }, scripts = {"/metagui/sbq/build.lua"}, ui = "starbecue:dialogueBox" }}
	end
end

function preservedStorage()
    return sb.jsonMerge(old.preservedStorage(), {
		settings = storage.settings
	})
end

function sbq.passiveStatChanges(dt)
	if (storage.isHorny ~= false) then
		local hornyPercent = status.resourcePercentage("horny")
		if hornyPercent < status.stat("hornyPassiveLimit") then
			status.modifyResource("horny", status.stat("hornyDelta") * dt * status.resourcePercentage("food"))
		end
		if hornyPercent >= 1 then
			if sbq.timer("hornyReset", 5, function ()
				status.resetResource("horny")
			end) then
				if sbq.occupant then
					local entitys = {}
					local players = {}
					for i, occupant in pairs(sbq.occupant) do
						local location = occupant.location
						local locationData = sbq.predatorConfig.locations[location]
						for _, satisfy in ipairs((locationData or {}).satisfiesPred or {}) do
							if satisfy == "horny" then
								world.sendEntityMessage(sbq.occupantHolder, "causedClimax", occupant.id)
								if world.entityType(occupant.id) == "player" then
									table.insert(players, { occupant.id, location })
								else
									table.insert(entitys, { occupant.id, location })
								end
							end
						end
					end
					local chosen
					if players[1] then
						chosen = players[math.random(#players)]
					elseif entitys[1] then
						chosen = entitys[math.random(#entitys)]
					end
					if not chosen then return end
					local settings = { predOrPrey = "pred", location = chosen[2] }
					sbq.getRandomDialogue(".climax", chosen[1], sb.jsonMerge(storage.settings, settings))
				end
			end
		end
	end
	if (storage.isSleepy ~= false) then
		if npc.loungingIn() ~= nil and (status.statusProperty("sbqType") ~= "driver") then
			status.modifyResource("rest", status.stat("restDelta") * dt * (4 * status.resourcePercentage("health")))
		else
			status.modifyResource("rest", status.stat("restDelta") * dt * (2 - status.resourcePercentage("health")))
		end
	end
end

-- I fucking hate starbound
function recruitable.generateRecruitInfo()
	local rank = config.getParameter("crew.rank") or storage.recruitRank or recruitable.generateRank()
	local parameters = {
		level = npc.level(),
		identity = npc.humanoidIdentity(),
		scriptConfig = {
			personality = personality(),
			crew = {
				rank = rank
			},
            initialStorage = preservedStorage(),
			sbqSettings = storage.settings,
			uniqueId = config.getParameter("preservedUuid") or config.getParameter("uniqueId") or entity.uniqueId(),
			preservedUuid = config.getParameter("preservedUuid") or config.getParameter("uniqueId") or
			entity.uniqueId()
		},
		statusControllerSettings = {
			statusProperties = {
				sbqPreyEnabled = status.statusProperty("sbqPreyEnabled"),
				sbqStoredDigestedPrey = status.statusProperty("sbqStoredDigestedPrey"),
                sbqCumulativeData = status.statusProperty("sbqCumulativeData"),
				speciesAnimOverrideSettings = status.statusProperty("speciesAnimOverrideSettings")
			}
		}
	}
	local poly = mcontroller.collisionPoly()
	if #poly <= 0 then poly = nil end

	local name = world.entityName(entity.id())

	if not entity.uniqueId() then
	  world.setUniqueId(entity.id(), sb.makeUuid())
	end

	storage.statusText = storage.statusText or randomStatusText(personalityType())

	return {
		name = name,
		uniqueId = entity.uniqueId(),
		portrait = world.entityPortrait(entity.id(), "full"),
		collisionPoly = poly,
		statusText = storage.statusText,
		rank = rank,
		uniform = storage.crewUniform,
		status = getCurrentStatus(),
		storage = preservedStorage(),
		config = {
			species = npc.species(),
			type = npc.npcType(),
			seed = npc.seed(),
			parameters = parameters
		}
	}
end
