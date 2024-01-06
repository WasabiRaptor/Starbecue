---@diagnostic disable: undefined-global

function ChargeFire:update(dt, fireMode, shiftHeld)
	WeaponAbility.update(self, dt, fireMode, shiftHeld)

	self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)

	if self.fireMode == (self.activatingFireMode or self.abilitySlot) then
		if self.cooldownTimer == 0
		and not self.weapon.currentAbility
		and not world.lineTileCollision(mcontroller.position(), self:firePosition())
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

function ChargeFire:fireProjectile()

	local params = copy(self.chargeLevel.projectileParameters or {})
	if sizeRayHoldingShift then
		world.sendEntityMessage(entity.id(), "animOverrideScale", params.animOverrideScale, params.animOverrideScaleDuration)
		return
	end
	local projectileCount = self.chargeLevel.projectileCount or 1

	params.power = (self.chargeLevel.baseDamage * config.getParameter("damageLevelMultiplier")) / projectileCount
	params.powerMultiplier = activeItem.ownerPowerMultiplier()

	local spreadAngle = util.toRadians(self.chargeLevel.spreadAngle or 0)
	local totalSpread = spreadAngle * (projectileCount - 1)
	local currentAngle = totalSpread * -0.5
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
