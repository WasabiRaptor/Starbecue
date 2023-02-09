function init()
	object.setInteractive(true)
	if object.direction() < 1 then
		animator.setGlobalTag("flip", "?flipx") -- unflip the flip even though I told it not to flip in the first place
	end
end

function onInteraction(args)
	if args.source[1] < 0 then
		animator.setAnimationState("toy", "right", true)
	else
		animator.setAnimationState("toy", "left", true)
	end
end

function onNpcPlay(npcId)
	local args = {
		source = entity.distanceToEntity(npcId),
		sourceId = npcId
	}
	onInteraction(args)
end
