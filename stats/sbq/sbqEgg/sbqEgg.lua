require "/scripts/vec2.lua"

local egg
local explode = false
local image
local totalCracks
local broken = false
local controlParameters = {}
local persistent = false

function replace(from, to)
	if not to then return "" end
	local directive = "?replace;"
	for i, f in ipairs(from) do
		directive = directive .. f .. "=" .. to[i]:sub(1,6) .. ";"
	end
	return directive
end

function init()
	egg = egg or status.statusProperty(effect.name()) or config.getParameter("eggParameters")
	persistent = config.getParameter("persistent") or false
	if not egg.directives then
		egg.directives = ""
		egg.colors = egg.colors or {}
		local colors = config.getParameter("colors") or {}
		local baseColors = config.getParameter("baseColors") or {}
		for _, color in ipairs(config.getParameter("colorOrder") or {}) do
			egg.colors[color] = egg.colors[color] or colors[color][math.random(#colors[color])]
			egg.directives = egg.directives..replace(baseColors[color], egg.colors[color])
		end
	end
	animator.setGlobalTag("directives", egg.directives)
	image = config.getParameter("image")
	animator.setGlobalTag("image", image)

	totalCracks = config.getParameter("cracks")
	effect.setParentDirectives(config.getParameter("directives") or "")

	controlParameters = config.getParameter("controlParameters") or {}
	effect.addStatModifierGroup({ { stat = "sbqEntrapped", amount = 1 } })
	effect.addStatModifierGroup(config.getParameter("statModifiers") or {})

	self.angularVelocity = 0
	self.angle = 0
	self.ballRadius = config.getParameter("ballRadius")

	effect.setToolUsageSuppressed(true)
end

local moving
local charge = 0
function update(dt)
	mcontroller.controlParameters(controlParameters)
	if persistent and ((effect.duration() or 0) < 10) then
		effect.modifyDuration(10)
	end
	if egg.cracks >= totalCracks then
		effect.expire()
	end

	if mcontroller.walking() or mcontroller.running() then
		if not moving then
			moving = true
			if math.random() > 0.5 then
				egg.cracks = egg.cracks + 1
				animator.setGlobalTag("cracks", tostring(egg.cracks))
			end
			if mcontroller.walking() then
				animator.setGlobalTag("direction", (mcontroller.movingDirection() == -1) and "left" or "right")
			end
		end
	else
		moving = false
		animator.setGlobalTag("direction", "idle")
	end
	if mcontroller.jumping() and (charge > 1) then
		egg.cracks = totalCracks
		explode = true
	end
	if mcontroller.crouching() then
		charge = charge + dt
	else
		charge = math.max(0, charge-dt)
	end
	updateAngularVelocity(dt)
	animator.resetTransformationGroup("rotation")
	animator.rotateTransformationGroup("rotation", mcontroller.rotation())
end

function updateAngularVelocity(dt)
	if mcontroller.groundMovement() then
	  -- If we are on the ground, assume we are rolling without slipping to
	  -- determine the angular velocity
	  local positionDiff = world.distance(self.lastPosition or mcontroller.position(), mcontroller.position())
	  self.angularVelocity = -vec2.mag(positionDiff) / dt / self.ballRadius

	  if positionDiff[1] > 0 then
		self.angularVelocity = -self.angularVelocity
	  end
	end
	self.angle = math.fmod(math.pi * 2 + self.angle + self.angularVelocity * dt, math.pi * 2)
	mcontroller.setRotation(self.angle)
	self.lastPosition = mcontroller.position()
end


function uninit()
	effect.setToolUsageSuppressed(false)
	if not broken then
		status.setStatusProperty(effect.name(), egg)
	end
	mcontroller.setRotation(0)
end

function onExpire()
	status.setStatusProperty(effect.name(), nil)
	broken = true

	local shardsImage = config.getParameter("shardsImage")
	local shard = "?addmask="..(shardsImage)..":"
	local blend = string.format("?blendmult=%s:%s.idle.1", image, egg.cracks)
	local blendShards = config.getParameter("blendShards")
	local fast = 1
	if explode or (math.random(1000) == 1) then
		fast = 10
		world.spawnProjectile("sbqMemeExplosion", mcontroller.position())
	end
	for i = 1, config.getParameter("shards") do
		world.spawnProjectile( "sbqEggShard", mcontroller.position(), entity.id(), {(math.random(-1,1) * math.random()), math.random()}, false, {
			processing = (blendShards and ("?blendmult="..shardsImage..":"..tostring(i)) or blend)..shard..tostring(i)..egg.directives,
			timeToLive = math.random(1,3) + math.random(),
			speed = (math.random(5,10) + math.random()) * fast
		})
	end

	local dropItem = config.getParameter("dropItem")
	if dropItem then
		egg.cracks = 0
		dropItem.parameters.eggParameters = sb.jsonMerge(dropItem.parameters.eggParameters, egg)
		world.spawnItem(dropItem, mcontroller.position())
	end
end
