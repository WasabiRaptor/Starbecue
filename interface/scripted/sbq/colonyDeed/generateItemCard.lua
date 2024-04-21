require"/scripts/any/SBQ_util.lua"
function sbq.generateNPCItemCard(tenant)
	local npcConfig = root.npcConfig(tenant.type)

	local item = root.assetJson("/sbqItemTemplates.config:npcCard")
	if npcConfig.scriptConfig.isOC then
		item.parameters.rarity = "rare"
	elseif npcConfig.scriptConfig.sbqNPC then
		item.parameters.rarity = "uncommon"
	end
	local eid = world.getUniqueEntityId(tenant.uniqueId)
	if eid then
		item.parameters.preySize = sbq.getEntitySize(eid)
	end

	item.parameters.shortdescription = ((tenant.overrides or {}).identity or {}).name or ""
	item.parameters.inventoryIcon = root.npcPortrait("bust", tenant.species, tenant.type, tenant.level or 1, tenant.seed, tenant.overrides)
	item.parameters.description = (npcConfig.scriptConfig or {}).cardDesc or ""
	item.parameters.tooltipFields.collarNameLabel = sbq.createdDate()
	item.parameters.tooltipFields.objectImage = root.npcPortrait("full", tenant.species, tenant.type, tenant.level or 1, tenant.seed, tenant.overrides)
	item.parameters.tooltipFields.subtitle = tenant.type
	item.parameters.tooltipFields.collarIconImage = nil
	item.parameters.npcArgs = {
		npcSpecies = tenant.species,
		npcSeed = tenant.seed,
		npcType = tenant.type,
		npcLevel = tenant.level,
		npcParam = tenant.overrides,
		npcSpawn = tenant.spawn
	}
	return item
end
