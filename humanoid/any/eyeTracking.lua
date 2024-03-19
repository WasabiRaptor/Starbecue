function sbq.eyeTracking()
	local targetDistance = sbq.globalToLocal(sbq.targetPosition(), animator.partPoint("eyes", "eyePos"))
	local targetAngle = vec2.angle(targetDistance) * 180 / math.pi
	if (targetDistance[1] < (sbq.voreConfig.eyeTrackingDeadzone[1][1])) or
		(targetDistance[1] > (sbq.voreConfig.eyeTrackingDeadzone[1][2]))
	then
		if ((targetAngle > 292) or (targetAngle < 68)) then
			animator.setGlobalTag("eyesX", "1")
		elseif ((targetAngle > 112) and (targetAngle < 248)) then
			animator.setGlobalTag("eyesX", "-1")
		end
	else
		animator.setGlobalTag("eyesX", "0")
	end
	if (targetDistance[2] < (sbq.voreConfig.eyeTrackingDeadzone[2][1])) or
		(targetDistance[2] > (sbq.voreConfig.eyeTrackingDeadzone[2][2]))
	then
		if ((targetAngle > 22) and (targetAngle < 158)) then
			animator.setGlobalTag("eyesY", "1")
		elseif ((targetAngle > 202) and (targetAngle < 338)) then
			animator.setGlobalTag("eyesY", "-1")
		end
	else
		animator.setGlobalTag("eyesY", "0")
	end
end
