function sbq.eyeTracking()
	local targetDistance = sbq.globalToLocal(sbq.targetPosition(), animator.partPoint("eyes", "eyePos"))
	local targetAngle = vec2.angle(targetDistance) * 180 / math.pi
	local absDist = {math.abs(targetDistance[1]), math.abs(targetDistance[2])}
	if (absDist[1] > (sbq.voreConfig.eyeTrackingDeadzone[1])) then
		if ((targetAngle > 292) or (targetAngle < 68)) then
			animator.setGlobalTag("eyesX", (absDist[1] > (sbq.voreConfig.eyeTrackingFarDist or 10)) and "2" or "1")
		elseif ((targetAngle > 112) and (targetAngle < 248)) then
			animator.setGlobalTag("eyesX", (absDist[1] > (sbq.voreConfig.eyeTrackingFarDist or 10)) and "-2" or "-1")
		else
			animator.setGlobalTag("eyesX", "0")
		end
	else
		animator.setGlobalTag("eyesX", "0")
	end
	if (absDist[2] > (sbq.voreConfig.eyeTrackingDeadzone[2])) then
		if ((targetAngle > 22) and (targetAngle < 158)) then
			animator.setGlobalTag("eyesY", "1")
		elseif ((targetAngle > 202) and (targetAngle < 338)) then
			animator.setGlobalTag("eyesY", "-1")
		else
			animator.setGlobalTag("eyesY", "0")
		end
	else
		animator.setGlobalTag("eyesY", "0")
	end
end
