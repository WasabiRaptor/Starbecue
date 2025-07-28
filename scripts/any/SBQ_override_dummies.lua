-- dummies to override with entity specific ones
function sbq.collisionArea()
	return 1
end
function sbq.facingDirection()
	return 1
end
function sbq.getScale()
	return 1
end

function sbq.entityId()
	return entity.id()
end

function sbq.targetPosition()
	return entity.position()
end

function sbq.species()
	return sbq.voreConfig.entitySpecies or sbq.voreConfig.species or "sbq_dummy"
end
function sbq.gender()
	return sbq.voreConfig.entityGender or "none"
end

function sbq.directory()
	return "/humanoid/any/"
end

function sbq.say(line, tags, config)
end

function sbq.sayPortrait(line, portrait, tags, config)
end

function sbq.parentEntity()
end
function sbq.getItemSlot(slot)
end

function sbq.setLoungeControlHeld(control)
end
function sbq.releaseLoungeControl(control)
end
function sbq.isLoungeControlHeld(control)
end

function sbq.loungingIn()
end

function sbq.checkStarpounds(slot)
	return false
end
