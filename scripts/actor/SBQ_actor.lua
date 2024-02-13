function sbq.actorInit()
	sbq.facingDirection = mcontroller.facingDirection
    sbq.scale = mcontroller.scale
    sbq.area = mcontroller.area

    sbq.setProperty = status.setStatusProperty

	sbq.stat = status.stat
    sbq.statPositive = status.statPositive

	sbq.isResource = status.isResource
    sbq.resource = status.resource
    sbq.resourcePositive = status.resourcePositive
    sbq.setResource = status.setResource
    sbq.modifyResource = status.modifyResource
    sbq.giveResource = status.giveResource
    sbq.consumeResource = status.consumeResource
    sbq.overConsumeResource = status.overConsumeResource
	sbq.resourceLocked = status.resourceLocked
    sbq.setResourceLocked = status.setResourceLocked
    sbq.resetResource = status.resetResource
	sbq.resetAllResources = status.resetAllResources
    sbq.resourceMax = status.resourceMax
    sbq.resetAllResources = status.resetAllResources
    sbq.resourcePercentage = status.resourcePercentage
	sbq.setResourcePercentage = status.setResourcePercentage
	sbq.modifyResourcePercentage = status.modifyResourcePercentage

	sbq.setStatModifiers = status.setPersistentEffects
end
