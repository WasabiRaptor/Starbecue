---@diagnostic disable: undefined-global

local switchAbility = {
	primary = "alt",
	alt = "primary"
}
local hueshift = 0
function ChargeFire:currentChargeLevel()
	hueshift = math.max(-45, math.min(45, hueshift + math.random(10) * ({1,0,-1})[math.random(3)]))
	local bestChargeTime = 0
	local bestChargeLevel
	for i, chargeLevel in pairs(self.chargeLevels) do
		if self.chargeTimer >= chargeLevel.time and self.chargeTimer >= bestChargeTime then
			animator.setGlobalTag("charge", i)
			bestChargeTime = chargeLevel.time
			bestChargeLevel = chargeLevel
		end
    end
	animator.setGlobalTag("glowdirectives", "?hueshift="..hueshift)
	return bestChargeLevel
end

function ChargeFire:fire()
	local sizeRayMisfire
	if math.random()<0.33 and not sizeRayHoldingShift then
		sizeRayMisfire = true
		sizeRayHoldingShift = not sizeRayHoldingShift
	end
	if math.random()<0.33 then
		sizeRayMisfire = true
		local abilityName = sizeRayWhichFireMode
		if math.random()<0.5 then
			abilityName = switchAbility[sizeRayWhichFireMode]
		end
		local otherAbility = config.getParameter(abilityName.."Ability")
        self.chargeLevel = copy(otherAbility.chargeLevels[math.random(#otherAbility.chargeLevels)])
		self.chargeTimer = math.random(0, self.chargeTimer * 2)
    end

	if not sizeRayHoldingShift then
		if world.lineTileCollision(mcontroller.position(), self:firePosition()) then
			animator.setAnimationState("firing", self.chargeLevel.fireAnimationState or "fire")
			self.cooldownTimer = self.chargeLevel.cooldown or 0
			self:setState(self.cooldown, self.cooldownTimer)
			return
		end
	end

	if sizeRayMisfire then
		animator.playSound("error")
	end

	self.weapon:setStance(self.stances.fire)

	animator.setAnimationState("firing", self.chargeLevel.fireAnimationState or "fire")
	animator.playSound(self.chargeLevel.fireSound or "fire")

	self:fireProjectile()

	if self.stances.fire.duration then
		util.wait(self.stances.fire.duration)
	end

	self.cooldownTimer = (self.chargeLevel.cooldown or 0)

	self:setState(self.cooldown, self.cooldownTimer)
end
