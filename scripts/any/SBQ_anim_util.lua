sbq_animator = {
	transforms = {}
}
function sbq_animator.setTranslation(transformGroup, translation)
	sbq_animator.transforms[transformGroup] = sbq_animator.transforms[transformGroup] or {}
	local transforms = sbq_animator.transforms[transformGroup]
	if (not transforms.translate) or (not vec2.eq(transforms.translate, translation)) then
		transforms.translate = translation
		sbq_animator.doTransforms(transformGroup)
	end
end
function sbq_animator.setRotation(transformGroup, rotation, rotationCenter)
	sbq_animator.transforms[transformGroup] = sbq_animator.transforms[transformGroup] or {}
	local transforms = sbq_animator.transforms[transformGroup]
	if (transforms.rotate ~= rotation) or (not vec2.eq(transforms.rotationCenter or {0,0}, rotationCenter or {0,0})) then
		transforms.rotate = rotation
		transforms.rotationCenter = rotationCenter
		sbq_animator.doTransforms(transformGroup)
	end
end
function sbq_animator.setScale(transformGroup, scale, scaleCenter)
	sbq_animator.transforms[transformGroup] = sbq_animator.transforms[transformGroup] or {}
	local transforms = sbq_animator.transforms[transformGroup]
	if ((not transforms.scale) or (not vec2.eq(transforms.scale, scale))) or (not vec2.eq(transforms.scaleCenter or {0,0}, scaleCenter or {0,0})) then
		transforms.scale = scale
		transforms.scaleCenter = scaleCenter
		sbq_animator.doTransforms(transformGroup)
	end
end

function sbq_animator.doTransforms(transformGroup)
	sbq_animator.transforms[transformGroup] = sbq_animator.transforms[transformGroup] or {}
	local transforms = sbq_animator.transforms[transformGroup]
	animator.resetTransformationGroup(transformGroup)
	if transforms.scale then
		animator.scaleTransformationGroup(transformGroup, transforms.scale, transforms.scaleCenter)
	end
	if transforms.rotate then
		animator.rotateTransformationGroup(transformGroup, transforms.rotate, transforms.rotationCenter)
	end
	if transforms.translate then
		animator.translateTransformationGroup(transformGroup, transforms.translate)
	end
end
