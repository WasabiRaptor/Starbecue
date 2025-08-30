sbq = {}
require("/scripts/any/SBQ_util.lua")

function init()
	object.setInteractive(true)
	self.timerList = {}

	message.setHandler("sbqSay", function (_,_, string, tags)
		object.say(string, tags)
	end)
end

function onInteraction(args)
	local dialogueBoxData = {
		dialogueTreeStart = config.getParameter("dialogueTreeStart"),
		dialogueTree = sbq.fetchConfigArray(config.getParameter("dialogueTree")),
		shopRecipes = config.getParameter("shopRecipes")
	}
	return {"ScriptPane", { data = {sbq = dialogueBoxData}, gui = { }, scripts = {"/metagui/sbq/build.lua"}, ui = "starbecue:shop" }}
end

function update(dt)
	checkTimers(dt)
	eyeTracking()

	randomTimer("blink", 10, 15, function() animator.setAnimationState("emote", "blink") end)
end

function die()
end

function eyeTracking()
	local X = 0
	local Y = 0

	local headPos = {-0.375, 6.75}
	local worldHeadPos = object.toAbsolutePosition(headPos)
	local target = getVisibleEntity(world.playerQuery(worldHeadPos, 50 ))
	if not target then target = getVisibleEntity(world.npcQuery(worldHeadPos, 50 )) end

	if target ~= nil then
		local targetPos = world.entityPosition(target)
		local targetDist = world.distance(targetPos, worldHeadPos)
		world.debugLine(worldHeadPos, targetPos, {72, 207, 180})

		local angle = math.atan(targetDist[2], targetDist[1]) * 180/math.pi
		if angle <= 15 and angle >= -15 then
			X = 1 * object.direction()
			Y = 0
		elseif angle <= 75 and angle > 15 then
			X = 1 * object.direction()
			Y = 1
		elseif angle <= 105 and angle > 75 then
			X = 0
			Y = 1
		elseif angle <= 165 and angle > 105 then
			X = -1 * object.direction()
			Y = 1
		elseif angle > 165 then
			X = -1 * object.direction()
			Y = 0

		elseif angle >= -75 and angle < -15 then
			X = 1 * object.direction()
			Y = -1
		elseif angle >= -105 and angle < -75 then
			X = 0
			Y = -1
		elseif angle >= -165 and angle < -105 then
			X = -1 * object.direction()
			Y = -1
		elseif angle < -165 then
			X = -1 * object.direction()
			Y = 0
		end

		if math.abs(targetDist[1]) > 10 then
			X = X * 2
		end
	end
	animator.setGlobalTag("eyesX", X)
	animator.setGlobalTag("eyesY", Y)
end

function getVisibleEntity(entities)
	for _, id in ipairs(entities) do
		if entity.entityInSight(id) then
			return id
		end
	end
end

function randomTimer(name, min, max, callback)
	if name == nil or self.timerList[name] == nil then
		local timer = {
			targetTime = (math.random(min * 100, max * 100))/100,
			currTime = 0,
			callback = callback
		}
		if name ~= nil then
			self.timerList[name] = timer
		else
			table.insert(self.timerList, timer)
		end
		return true
	end
end

function timer(name, time, callback)
	if name == nil or self.timerList[name] == nil then
		local timer = {
			targetTime = time,
			currTime = 0,
			callback = callback
		}
		if name ~= nil then
			self.timerList[name] = timer
		else
			table.insert(self.timerList, timer)
		end
		return true
	end
end

function checkTimers(dt)
	for name, timer in pairs(self.timerList) do
		timer.currTime = timer.currTime + dt
		if timer.currTime >= timer.targetTime then
			if timer.callback ~= nil then
				timer.callback()
			end
			self.timerList[name] = nil
		end
	end
end
