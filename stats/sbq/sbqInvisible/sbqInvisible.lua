function init()
	effect.setParentDirectives("crop;0;0;0;0")
	effect.addStatModifierGroup({
		{stat = "invisible", amount = 1},
	})
	script.setUpdateDelta(0)
end

function update(dt)
end

function uninit()
end
