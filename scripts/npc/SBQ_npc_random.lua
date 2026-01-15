local old = {
	init = init
}
function init()
	old.init()
	local convertType = config.getParameter("sbqConvertType")
	if config.getParameter("sbqConvertType") and not storage.sbqConvertRoll then
		storage.sbqConvertRoll = true
		if entity.uniqueId() then return end
		local speciesConfig = root.speciesConfig(npc.species())
		if not speciesConfig.sbqCompatible then return end

		if config.getParameter("sbqNPC")
			or config.getParameter("uniqueId")
			or ((config.getParameter("behaviorConfig") or {}).beamOutWhenNotInUse == true)
			or npc.humanoidIdentity().imagePath ~= nil
		then
			return
		end
		if tenant then
			if (math.random() <= math.max(config.getParameter("sbqConvertChance") or 0, speciesConfig.sbqConvertChance or 0, root.assetJson("/sbq.config:convertChance"))) then
				sbq.timer("maybeConvert", 0.1,
					function()
						if sbq.parentEntity() or entity.uniqueId() then
							return
						end
						if (config.getParameter("sbqConvertSpecies") or {})[npc.species()] then
							local speciesList = config.getParameter("sbqConvertSpeciesList") or root.assetJson("/sbqTFAny.config")
							local identity, parameters = root.generateHumanoidIdentity(speciesList[math.random(#speciesList)], npc.seed(), npc.gender())
							npc.setHumanoidParameters(parameters)
							npc.setHumanoidIdentity(identity)
						end
						sbq.tenant_setNpcType(convertType)
					end)
			end
		end
	end
end
