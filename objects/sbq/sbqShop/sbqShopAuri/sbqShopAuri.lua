
local occupantHolder = nil

function init()
	object.setInteractive(true)
	self.timerList = {}
	self.offsets = {enabled = false, parts = {}}
	self.rotating = {enabled = false, parts = {}}
	self.animStateData = root.assetJson("/objects/sbq/sbqShop/sbqShopAuri/sbqShopAuri.animation").animatedParts.stateTypes
	self.animFunctionQueue = {}
	for statename, state in pairs(self.animStateData) do
		state.animationState = {
			anim = state.default,
			priority = state.states[state.default].priority,
			cycle = state.states[state.default].cycle,
			frames = state.states[state.default].frames,
			time = 0
		}
		self.animFunctionQueue[statename] = {}
		state.tag = nil
	end

	message.setHandler("sbqRefreshDialogueBoxData", function (_,_, id, isPrey)
		talkingWithPrey = (isPrey == "prey")
		dialogueBoxOpen = 0.5
		return { occupantHolder = occupantHolder }
	end)
	message.setHandler("sbqSay", function (_,_, string, tags)
		object.say(string, tags)
	end)
end

function onInteraction(args)
	local dialogueBoxData = { dialogueStepScripts = config.getParameter("dialogueStepScripts"), dialogueTreeStart = config.getParameter("dialogueTreeStart"), settings = storage.sbqSettings, dialogueTree = config.getParameter("dialogueTree"), defaultPortrait = config.getParameter("defaultPortrait"), defaultName = config.getParameter("defaultName"), portraitPath = config.getParameter("portraitPath"), occupantHolder = occupantHolder }
	return {"ScriptPane", { data = dialogueBoxData, gui = { }, scripts = {"/metagui/sbq/build.lua"}, ui = "starbecue:shop" }}
end

function update(dt)
	checkTimers(dt)
	eyeTracking()
	updateAnims(dt)
	doIdleAnims()
end

function die()
end


function doIdleAnims()
	randomTimer("blink", 10, 15, function() doAnim("emoteState", "blink") end)

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
			if type(name) == "number" then
				---@diagnostic disable-next-line: param-type-mismatch
				table.remove(self.timerList, name)
			else
				self.timerList[name] = nil
			end
		end
	end
end

function updateAnims(dt)
	for statename, state in pairs(self.animStateData) do
		state.animationState.time = state.animationState.time + dt
	end

	offsetAnimUpdate()
	rotationAnimUpdate()

	for statename, state in pairs(self.animStateData) do
		if state.animationState.time >= state.animationState.cycle then
			endAnim(state, statename)
		end
	end
end

function endAnim(state, statename)
	for _, func in pairs(self.animFunctionQueue[statename]) do
		func()
	end
	self.animFunctionQueue[statename] = {}

	if (state.tag ~= nil) and state.tag.reset then
		if state.tag.part == "global" then
			animator.setGlobalTag( state.tag.name, "" )
		else
			animator.setPartTag( state.tag.part, state.tag.name, "" )
		end
		state.tag = nil
	end
end

function doAnims( anims, force )
	for state,anim in pairs( anims or {} ) do
		if state == "offset" then
			offsetAnim( anim )
		elseif state == "rotate" then
			rotate( anim )
		elseif state == "tags" then
			setAnimTag( anim )
		elseif state == "priority" then
			changePriorityLength( anim )
		else
			doAnim( state.."State", anim, force)
		end
	end
end

function doAnim( state, anim, force )
	local oldPriority = (self.animStateData[state].animationState or {}).priority or 0
	local newPriority = (self.animStateData[state].states[anim] or {}).priority or 0
	local isSame = animator.animationState(state) == anim
	local force = force
	local priorityHigher = ((newPriority >= oldPriority) or (newPriority == -1))
	if (not isSame and priorityHigher) or hasAnimEnded(state) or force then
		if isSame and (self.animStateData[state].states[animator.animationState(state)].mode == "end") then
			force = true
		end
		self.animStateData[state].animationState = {
			anim = anim,
			priority = newPriority,
			cycle = self.animStateData[state].states[anim].cycle,
			frames = self.animStateData[state].states[anim].frames,
			time = 0
		}
		animator.setAnimationState(state, anim, force)
	end
end

function queueAnimEndFunction(state, func, newPriority)
	if newPriority then
		self.animStateData[state].animationState.priority = newPriority
	end
	table.insert(self.animFunctionQueue[state], func)
end

function setAnimTag(anim)
	for _,tag in ipairs(anim) do
		self.animStateData[tag.owner.."State"].tag = {
			part = tag.part,
			name = tag.name,
			reset = tag.reset or true
		}
		if tag.part == "global" then
			animator.setGlobalTag( tag.name, tag.value )
		else
			animator.setPartTag( tag.part, tag.name, tag.value )
		end
	end
end

function changePriorityLength(anim)
	for state, data in pairs(anim) do
		self.animStateData[state.."State"].animationState.priority = data[1] or self.animStateData[state.."State"].animationState.priority
		self.animStateData[state.."State"].animationState.cycle = data[2] or self.animStateData[state.."State"].animationState.cycle
	end
end

function offsetAnim( data )
	if data == self.offsets.data then
		if not self.offsets.enabled then self.offsets.enabled = true end
		return
	else
		for i, part in ipairs(self.offsets.parts) do
			for j, group in ipairs(part.groups) do
				animator.resetTransformationGroup(group)
			end
		end
	end

	self.offsets = {
		enabled = data ~= nil,
		data = data,
		parts = {},
		loop = data.loop or false,
		timing = data.timing or "body"
	}
	local continue = false
	for _, part in ipairs(data.parts or {}) do
		table.insert(self.offsets.parts, {
			x = part.x or {0},
			y = part.y or {0},
			groups = part.groups or {"headbob"},
			})
		if (part.x and #part.x > 1) or (part.y and #part.y > 1) then
			continue = true
		end
	end
	offsetAnimUpdate()
	if not continue then
		self.offsets.enabled = false
	end
end

function rotate( data )
	if data == self.rotating.data and self.rotating.enabled then return
	else
		for i, part in ipairs(self.rotating.parts) do
			for j, group in ipairs(part.groups) do
				animator.resetTransformationGroup(group)
			end
		end
	end

	self.rotating = {
		enabled = data ~= nil,
		data = data,
		frames = data.frames,
		parts = {},
		loop = data.loop or false,
		timing = data.timing or "body",

		frame = 1,
		index = 2,
		prevFrame = 0,
		prevIndex = 1

	}
	local continue = false
	for _, r in ipairs(data.parts or {}) do
		table.insert(self.rotating.parts, {
			groups = r.groups or {"frontarmsrotation"},
			center = r.center or {0,0},
			rotation = r.rotation or {0},
			last = r.rotation[1] or 0
		})
		if r.rotation and #r.rotation > 1 then
			continue = true
		end
	end
	rotationAnimUpdate()
	if not continue then
		self.rotating.enabled = false
	end
end

function offsetAnimUpdate()
	if self.offsets == nil or not self.offsets.enabled then return end
	local state = self.offsets.timing.."State"
	local ended, times, time = hasAnimEnded(state)
	if ended and not self.offsets.loop then self.offsets.enabled = false end
	local speed = self.animStateData[state].animationState.frames / self.animStateData[state].animationState.cycle
	local frame = math.floor(time * speed) + 1

	for _,r in ipairs(self.offsets.parts) do
		local x = r.x[ frame ] or r.x[#r.x] or 0
		local y = r.y[ frame ] or r.y[#r.y] or 0
		for i = 1, #r.groups do
			animator.resetTransformationGroup( r.groups[i] )
			animator.translateTransformationGroup( r.groups[i], { x / 8, y / 8 } )
		end
	end
end

function rotationAnimUpdate()
	if self.rotating == nil or not self.rotating.enabled then return end
	local state = self.rotating.timing.."State"
	local ended, times, time = hasAnimEnded(state)
	if ended and not self.rotating.loop then self.rotating.enabled = false end
	local speed = self.animStateData[state].animationState.frames / self.animStateData[state].animationState.cycle
	local frame = math.floor(time * speed)
	local index = frame + 1
	local nextFrame = frame + 1
	local nextIndex = index + 1

	if self.rotating.prevFrame ~= frame then
		if self.rotating.frames ~= nil then
			for i = 1, #self.rotating.frames do
				if (self.rotating.frames[i] == frame) then
					self.rotating.prevFrame = frame
					self.rotating.prevIndex = i

					self.rotating.frame = self.rotating.frames[i + 1] or frame + 1
					self.rotating.index = i + 1
				end
				if self.rotating.loop and (i == #self.rotating.frames) then
					self.rotating.prevFrame = frame
					self.rotating.prevIndex = i

					self.rotating.frame = 0
					self.rotating.index = 1
				end
			end
		else
			self.rotating.prevFrame = self.rotating.frame
			self.rotating.frame = nextFrame

			self.rotating.prevIndex = self.rotating.index
			self.rotating.index = nextIndex
		end
	end

	local currTime = time * speed
	local progress = (currTime - self.rotating.prevFrame)/(math.abs(self.rotating.frame - self.rotating.prevFrame))

	for _, r in ipairs(self.rotating.parts) do
		local previousRotation = r.rotation[self.rotating.prevIndex] or r.last
		local nextRotation = r.rotation[self.rotating.index] or previousRotation
		local rotation = previousRotation + (nextRotation - previousRotation) * progress
		r.last = previousRotation

		for _, group in ipairs(r.groups) do
			animator.resetTransformationGroup( group )
			animator.rotateTransformationGroup( group, (rotation * math.pi/180), r.center)
		end
	end
end


function hasAnimEnded(state)
	local ended = (self.animStateData[state].animationState.time >= self.animStateData[state].animationState.cycle)
	local times = math.floor(self.animStateData[state].animationState.time/self.animStateData[state].animationState.cycle)
	local currentCycle = (self.animStateData[state].animationState.time - (self.animStateData[state].animationState.cycle*times))
	return ended, times, currentCycle
end
