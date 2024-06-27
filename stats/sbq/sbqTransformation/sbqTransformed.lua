local doRevert = true
function init()
	message.setHandler("sbqClearTransformed", function ()
		doRevert = false
		effect.expire()
	end)
	effect.addStatModifierGroup({{stat = effect.name(), amount = 1}})
end
function onExpire()
	if doRevert then
		world.sendEntityMessage(entity.id(), "sbqRevertTF")
	end
end
