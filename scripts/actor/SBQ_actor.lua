local old = {
	faceEntity = faceEntity
}

function sbq.actorInit()
	sbq.pronouns = root.assetJson("/sbqPronouns.config")

	sbq.facingDirection = mcontroller.facingDirection
	sbq.scale = mcontroller.scale
	sbq.area = mcontroller.area

	sbq.entityId = entity.id
	sbq.setProperty = status.setStatusProperty

	sbq.stat = status.stat
	sbq.statPositive = status.statPositive

	sbq.isResource = status.isResource
	sbq.resource = status.resource
	sbq.resourcePositive = status.resourcePositive
	sbq.setResource = status.setResource
	sbq.modifyResource = status.modifyResource
	sbq.giveResource = status.giveResource
	sbq.consumeResource = status.consumeResource
	sbq.overConsumeResource = status.overConsumeResource
	sbq.resourceLocked = status.resourceLocked
	sbq.setResourceLocked = status.setResourceLocked
	sbq.resetResource = status.resetResource
	sbq.resetAllResources = status.resetAllResources
	sbq.resourceMax = status.resourceMax
	sbq.resetAllResources = status.resetAllResources
	sbq.resourcePercentage = status.resourcePercentage
	sbq.setResourcePercentage = status.setResourcePercentage
	sbq.modifyResourcePercentage = status.modifyResourcePercentage

	sbq.setStatModifiers = status.setPersistentEffects
	sbq.clearStatModifiers = status.clearPersistentEffects
end
local responseMap = {
	yes = true,
	noYes = true,
	no = false
}
function sbq.actorMessages()
	sbq.actionWillingness = {
		dom = {},
		sub = {}
	}
	message.setHandler("sbqGuiMessage", function(_, _, ...)
		world.sendEntityMessage(entity.id(), ...)
	end)
	message.setHandler("sbqRefreshLocationData", function(_, _, id, locationData)
		sbq.setCurrentLocationData(locationData)
	end)
	message.setHandler("sbqPromptAction", function(_, _, id, action, isDom)
		local willingnessTable = sbq.actionWillingness[(isDom and "sub") or "dom"]
		if willingnessTable[action] == nil then
			local settings = sbq.settings[(isDom and "subBehavior") or "domBehavior"][action]
			if math.random() < settings.willingness then
				willingnessTable[action] = "yes"
			else
				willingnessTable[action] = "no"
            end
			sbq.timer(action.."ClearWillingness", 60, function ()
				willingnessTable[action] = nil
			end)
		end
		return {responseMap[willingnessTable[action] or "no"] or false, isDom, willingnessTable[action] or "no", action, entity.id()}
	end)
end

function sbq.setCurrentLocationData(locationData)
	sbq.currentLocationData = locationData
	sbq.checkComfortLevel()
end

function sbq.checkComfortLevel()
	local comfortLevel = 0
	local adjectives = {}
	local loungeEffects = status.getPersistentEffects("lounging")
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

local struggleDirections = {false,"Left","Right","Up","Down"}
function sbq.struggleBehavior(dt)
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
	local loungeAnchor = world.entityCurrentLounge(args.entity)
	if loungeAnchor and loungeAnchor.entityId == entity.id() then return false end
	return old.faceEntity(args, board)
end
