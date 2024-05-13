function init()
	effect.addStatModifierGroup({{stat = effect.name(), amount = 1}})
end
function onExpire()
	world.sendEntityMessage(entity.id(), "sbqRevertTF")
end
