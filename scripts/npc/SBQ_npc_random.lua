local old = {
    init = init
}
function init()
    old.init()
    sbq.rollConvert()
	if not convert then
		if npc.getHumanoidParameter("sbqEnabled") and not config.getParameter("sbqNPC") then
			npc.setHumanoidParameter("sbqEnabled")
			npc.refreshHumanoidParameters()
		end
	end
end

function sbq.rollConvert()
	if config.getParameter("sbqConvertType") and not storage.sbqConvertRoll then
		storage.sbqConvertRoll = true
		if entity.uniqueId() then return end
		local speciesConfig = root.speciesConfig(npc.species())
		if not speciesConfig.voreConfig then return end

		if config.getParameter("sbqNPC")
			or config.getParameter("uniqueId")
			or ((config.getParameter("behaviorConfig") or {}).beamOutWhenNotInUse == true)
			or npc.humanoidIdentity().imagePath ~= nil
		then
			return
		end
		if tenant then
			convert = (math.random() <= math.max(config.getParameter("sbqConvertChance") or 0, speciesConfig.sbqConvertChance or 0, sbq.config.convertChance))
			if convert then
				sbq.timer("maybeConvert", 0.1,
					function()
						if sbq.parentEntity() or entity.uniqueId() then
							sbq.settingsInit()
							return
						end
						if npc.species() == config.getParameter("sbqConvertSpecies") then
							local speciesList = root.assetJson("/sbqTFAny.config")
							npc.setHumanoidIdentity(root.generateHumanoidIdentity(speciesList[math.random(#speciesList)], npc.seed(), npc.gender()))
						end
						convertBackType = npc.npcType()
						local convertType = config.getParameter("sbqConvertType")
						if convertType and convert then
							sbq.tenant_setNpcType(convertType)
						end
					end)
			end
		end
	end
end
