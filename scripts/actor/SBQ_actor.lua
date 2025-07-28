local old = {
	init = init or function () end,
	update = update or function () end,
	faceEntity = faceEntity
}
local responseMap = {
	yes = true,
	noYes = true,
	no = false
}
local seatToForce

function init()
	old.init()
	sbq.pronouns = root.assetJson("/sbqPronouns.config")

	sbq.facingDirection = mcontroller.facingDirection
	sbq.getScale = mcontroller.getScale
	sbq.collisionArea = mcontroller.collisionArea
	sbq.entityId = entity.id

	sbq.actionWillingness = {
		dom = {},
		sub = {}
	}
	sbq.expectedActions = {}
	message.setHandler("sbqRefreshLocationData", function(_, _, id, locationData, occupantData)
		sbq.setCurrentLocationData(id, locationData, occupantData)
	end)
	message.setHandler("sbqPromptAction", function(_, _, id, action, isDom)
		local willingnessTable = sbq.actionWillingness[(isDom and "sub") or "dom"]
		if willingnessTable[action] == nil then
			local settings = sbq.settings[(isDom and "subBehavior") or "domBehavior"][action] or {}
			if math.random() < (settings.willingness or 0) then
				willingnessTable[action] = "yes"
				sbq.setLoungeControlHeld("Shift")
				sbq.forceTimer("willingPreyTime", sbq.config.willingPreyTime * 60, function()
					sbq.releaseLoungeControl("Shift")
				end)
			else
				willingnessTable[action] = "no"
			end
			sbq.timer(action .. "ClearWillingness", 60, function()
				willingnessTable[action] = nil
			end)
		end
		if isDom and responseMap[willingnessTable[action] or "no"] then
			sbq.expectedActions[action] = true
		end
		return { responseMap[willingnessTable[action] or "no"] or false, isDom, willingnessTable[action] or "no", action,
			entity.id() }
	end)
	message.setHandler("sbqStruggleAction", function(_, _, id, action)
		sbq.struggleAction = action
	end)
	message.setHandler("sbqActionOccuring", function(_, _, id, action, cooldown)
		if sbq.expectedActions[action] then
			sbq.expectedActions[action] = nil
			return
		end
		if (action == sbq.struggleAction) and not sbq.isLoungeControlHeld("Shift") then
			if dialogueProcessor and sbq.settings.actionDialogue and dialogueProcessor.getDialogue(".forcingAction." .. action, id) then
				dialogueProcessor.speakDialogue()
			end
			if not cooldown then return end
			sbq.forceTimer("dialogueAfter", cooldown + sbq.config.afterDialogueDelay, function()
				if dialogueProcessor and sbq.settings.actionDialogue and dialogueProcessor.getDialogue(".forcingAction." .. action .. ".after", id) then
					dialogueProcessor.speakDialogue()
				end
			end)
			return
		else
			if dialogueProcessor and sbq.settings.actionDialogue and dialogueProcessor.getDialogue(".unpromptedAction." .. action, id) then
				dialogueProcessor.speakDialogue()
			end
			if not cooldown then return end
			sbq.forceTimer("dialogueAfter", cooldown + sbq.config.afterDialogueDelay, function()
				if dialogueProcessor and sbq.settings.actionDialogue and dialogueProcessor.getDialogue(".unpromptedAction." .. action .. ".after", id) then
					dialogueProcessor.speakDialogue()
				end
			end)
		end
	end)

	message.setHandler("sbqReleased", function(_, _, data)
		mcontroller.resetAnchorState()
		sbq.resetLounging()
		status.setStatusProperty("sbqProgressBar", 0)
		status.setStatusProperty("sbqProgressBarColor", {})
		seatToForce = nil
		status.setStatusProperty("sbqOccupantData", nil)
		sbq.checkStuck()
		sbq.timer("stuckCheck", 0.5, sbq.checkStuck)
	end)

	message.setHandler("sbqForceSit", function(_, _, data)
		local source, index = mcontroller.anchorState()
		if (source == data.source) and (index == data.index) then return end
		sbq.resetLounging()
        mcontroller.setPosition(world.entityPosition(data.source))
		local success, error = pcall(mcontroller.setAnchorState, data.source, data.index)
		if success then
			seatToForce = nil
        else
			seatToForce = data
			sb.logError(error)
		end
	end)

	status.setPersistentEffects("sbqActorScript", {
		{ stat = "sbqActorScript", amount = 1 } -- set this stat to mark that status primary has initialized
	})
end

function update(dt)
	old.update(dt)
	if seatToForce then
		if world.entityExists(seatToForce.source) then
			mcontroller.setPosition(world.entityPosition(seatToForce.source))
			local success, error = pcall(mcontroller.setAnchorState, seatToForce.source, seatToForce.index)
			if success then
				seatToForce = nil
			else
				sb.logError(error)
			end
		else
			seatToForce = nil
		end
	end
end

function sbq.setCurrentLocationData(id, locationData, occupantData)
	status.setStatusProperty("sbqOccupantData", occupantData)
	status.clearPersistentEffects("sbqMissingPred")
	sbq.currentLocationData = locationData
	sbq.forceTimer("strugglingDialogue", 5)
	sbq.checkComfortLevel()
end

function sbq.checkComfortLevel()
	local comfortLevel = 0
	local adjectives = {}
	local loungeEffects = status.getPersistentEffects("lounging") or {}
	for _, effect in ipairs(loungeEffects) do
		if type(effect) == "string" then
			local effectConfig = root.effectConfig(effect).effectConfig
			util.appendLists(adjectives, effectConfig.adjectives or {})
		end
	end
	-- until I define stuff for this we're just going to pretend
	local like = {
		soothing = true
	}
	local dislike = {
		melty = true
	}
	for _, adjective in ipairs(adjectives) do
		if like[adjective] then
			comfortLevel = comfortLevel + 1
		elseif dislike[adjective] then
			comfortLevel = comfortLevel - 1
		end
	end
	sbq.comfortLevel = comfortLevel
end

function sbq.size()
	return math.sqrt(sbq.collisionArea()) / sbq.config.sizeConstant
end

local struggleDirections = { false, "Left", "Right", "Up", "Down" }
function sbq.struggleBehavior(dt)
	if sbq.randomTimer("strugglingDialogue", sbq.voreConfig.strugglingDialogueMin or sbq.config.strugglingDialogueMin, sbq.voreConfig.strugglingDialogueMax or sbq.config.strugglingDialogueMax) and dialogueProcessor and dialogue.finished and sbq.settings.actionDialogue and not sbq.timerRunning("dialogueAfter") then
		if dialogueProcessor.getDialogue(".struggling", sbq.loungingIn()) then
			dialogueProcessor.speakDialogue()
		end
	end
	if sbq.timer("changeStruggleDirection", 2) then
		if true then -- do stuff with location data here to determine struggles later
			local dir = struggleDirections[math.random(#struggleDirections)]
			if dir then
				if sbq.randomTimer(dir .. "Press", 0, 2, function()
						sbq.releaseLoungeControl(dir)
					end) then
					sbq.setLoungeControlHeld(dir)
				end
			end
		end
	end
end

function faceEntity(args, board)
	if args.entity == nil or not world.entityExists(args.entity) then return false end
	local loungeId = world.entityAnchorState(args.entity)
	if loungeId == entity.id() then return false end
	return old.faceEntity(args, board)
end

function sbq.checkStuck()
	if mcontroller.isCollisionStuck() then -- copy of vanilla's "checkStuck" but without the lounge check
		-- sloppy catch-all correction for various cases of getting stuck in things
		-- due to bad spawn position, failure to exit loungeable (on ships), etc.
		local poly = mcontroller.collisionPoly()
		local pos = mcontroller.position()
		for maxDist = 2, 5 do
			local resolvePos = world.resolvePolyCollision(poly, pos, maxDist)
			if resolvePos then
				mcontroller.setPosition(resolvePos)
				break
			end
		end
	end
end
