
function init()
	effect.addStatModifierGroup(root.assetJson("/sbq.config:prey.statusEffects"))
	effect.setParentDirectives("?crop;0;0;0;0")
end

function update(dt)
	mcontroller.controlParameters({
		walkSpeed = 0,
		runSpeed = 0,
		flySpeed = 0,
		airJumpProfile = {
			jumpSpeed = 0,
			jumpInitialPercentage = 0,
			jumpHoldTime = 0.0
		},
		liquidJumpProfile = {
			jumpSpeed = 0,
			jumpInitialPercentage = 0,
			jumpHoldTime = 0.0
		}
	})
end

function uninit()

end
