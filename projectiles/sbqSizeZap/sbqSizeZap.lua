function uninit()
	for i, id in ipairs(world.entityQuery(mcontroller.position(), 2,{
		withoutEntityId = entity.id(), includedTypes = {"creature"}
	}) or {}) do
		world.sendEntityMessage(id, "animOverrideScale", config.getParameter("animOverrideScale") or 1, config.getParameter("animOverrideScaleDuration") or 1, projectile.sourceEntity(), config.getParameter("sourceWeapon") )
	end
end
