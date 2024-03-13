---@diagnostic disable: undefined-global

function ChargeFire:update(dt, fireMode, shiftHeld)
	WeaponAbility.update(self, dt, fireMode, shiftHeld)

	self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)

	if self.fireMode == (self.activatingFireMode or self.abilitySlot) then
		if self.cooldownTimer == 0
		and not self.weapon.currentAbility
		and not status.resourceLocked("energy") then
			animator.setGlobalTag("charge", "1")
			self:setState(self.charge)
		end
		self:currentChargeLevel()
	end
end

function ChargeFire:currentChargeLevel()
	local bestChargeTime = 0
	local bestChargeLevel
	for i, chargeLevel in pairs(self.chargeLevels) do
		if self.chargeTimer >= chargeLevel.time and self.chargeTimer >= bestChargeTime then
			animator.setGlobalTag("charge", i)
			bestChargeTime = chargeLevel.time
			bestChargeLevel = chargeLevel
		end
	end
	return bestChargeLevel
end

function ChargeFire:fire()
	if not sizeRayHoldingShift then
		if world.lineTileCollision(mcontroller.position(), self:firePosition()) then
			animator.setAnimationState("firing", self.chargeLevel.fireAnimationState or "fire")
			self.cooldownTimer = self.chargeLevel.cooldown or 0
			self:setState(self.cooldown, self.cooldownTimer)
			return
		end
	end

	self.weapon:setStance(self.stances.fire)

	animator.setAnimationState("firing", self.chargeLevel.fireAnimationState or "fire")
	animator.playSound(self.chargeLevel.fireSound or "fire")

	self:fireProjectile()

	if self.stances.fire.duration then
	  util.wait(self.stances.fire.duration)
	end

	self.cooldownTimer = self.chargeLevel.cooldown or 0

	self:setState(self.cooldown, self.cooldownTimer)
  end

function ChargeFire:fireProjectile()

	local params = copy(self.chargeLevel.projectileParameters or {})
	local projectileCount = self.chargeLevel.projectileCount or 1

	params.powerMultiplier = self.chargeTimer * 0.5

	local spreadAngle = util.toRadians(self.chargeLevel.spreadAngle or 0)
	local totalSpread = spreadAngle * (projectileCount - 1)
    local currentAngle = totalSpread * -0.5
	if sizeRayHoldingShift then
        local projectile = sb.jsonMerge(root.projectileConfig(self.chargeLevel.projectileType), params)
		return status.applySelfDamageRequest({
			hitType = "hit",
			damageType = projectile.damageType,
			damage = projectile.power * projectile.powerMultiplier * projectileCount,
			damageSourceKind = projectile.damageKind,
			sourceEntityId = entity.id()
        })
	end

    for i = 1, projectileCount do
		if params.timeToLive then
			params.timeToLive = util.randomInRange(params.timeToLive)
		end

		world.spawnProjectile(
			self.chargeLevel.projectileType,
			self:firePosition(),
			activeItem.ownerEntityId(),
			self:aimVector(currentAngle, self.chargeLevel.inaccuracy or 0),
			false,
			params
		)

		currentAngle = currentAngle + spreadAngle
	end
end
