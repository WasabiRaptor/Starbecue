---@diagnostic disable-next-line: undefined-global

local misfire = false
function GunFire:fireProjectile(projectileType, projectileParams, inaccuracy, firePosition, projectileCount)
	local params = sb.jsonMerge(self.projectileParameters, projectileParams or {})
	params.power = self:damagePerShot()
	params.powerMultiplier = activeItem.ownerPowerMultiplier()
    params.speed = util.randomInRange(params.speed)

	if not projectileType then
		projectileType = self.projectileType
	end
	if type(projectileType) == "table" then
		projectileType = projectileType[math.random(#projectileType)]
	end

	local projectileId = 0
	for i = 1, (projectileCount or self.projectileCount) do
		if params.timeToLive then
			params.timeToLive = util.randomInRange(params.timeToLive)
        end
		local data = activeItem.callOtherHandScript("transformationItemArgs")
        if not data then misfire = true return end
		if data.consume and (not ((player~=nil) and player.isAdmin())) then activeItem.callOtherHandScript("item.consume",1) end
		params = sb.jsonMerge(params, data)
		misfire = false
		projectileId = world.spawnProjectile(
			projectileType,
			firePosition or self:firePosition(),
			activeItem.ownerEntityId(),
			self:aimVector(inaccuracy or self.inaccuracy),
			false,
			params
		)
	end
	return projectileId
end

function GunFire:muzzleFlash()
	if misfire then animator.playSound("misfire") return end
	animator.setPartTag("muzzleFlash", "variant", math.random(1, self.muzzleFlashVariants or 3))
	animator.setAnimationState("firing", "fire")
	animator.burstParticleEmitter("muzzleFlash")
	animator.playSound("fire")

	animator.setLightActive("muzzleFlash", true)
  end
