---@diagnostic disable: undefined-global

local _init = init
local _update = update
sizeRayHoldingShift = false
sizeRayWhichFireMode = "primary"

sizeRayFireModeMap = {
	primary = "Shrink",
	alt = "Grow"
}

local _sizeRayAnimator_setAnimationState
function sizeRayAnimator_setAnimationState(state, anim, force, reversed)
	if anim ~= "off" then
		anim = anim..sizeRayFireModeMap[sizeRayWhichFireMode]
	end
	_sizeRayAnimator_setAnimationState(state, anim, force, reversed)
end

function init()
	_init()

	if type(_sizeRayAnimator_setAnimationState) ~= "function" then
		_sizeRayAnimator_setAnimationState = animator.setAnimationState
		animator.setAnimationState = sizeRayAnimator_setAnimationState
	end
end


function update(dt, fireMode, shiftHeld, controls)
	sizeRayHoldingShift = shiftHeld
	if fireMode ~= "none" then
		sizeRayWhichFireMode = fireMode
	end

	_update(dt, fireMode, shiftHeld, controls)
end
