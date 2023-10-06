function uninit()
	for i, id in ipairs(world.entityQuery(mcontroller.position(), 2,{
		withoutEntityId = entity.id(), includedTypes = {"creature"}
	}) or {}) do
		world.sendEntityMessage(id, "applyStatusEffect", "sbqPotionDart")
		world.sendEntityMessage(id, "sbqProjectileSource", projectile.sourceEntity())
	end
end
