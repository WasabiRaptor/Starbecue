

function removeOtherBellyEffects()
	local name = config.getParameter("effect")
	local bellyEffectList = root.assetJson("/sbqGeneral.config").bellyStatusEffects
	for _, effect in ipairs(bellyEffectList) do
		if effect ~= name then
			status.removeEphemeralEffect(effect)
		end
	end
end

require("/items/active/sbqTransformation/sbqDuplicatePotion/sbqGetIdentity.lua")

function doItemDrop()
	if self.dropItem and not self.droppedItem then
		self.droppedItem = true
		local drop = config.getParameter("itemDrop")
		if drop and getPreyEnabled(config.getParameter("digestType").."ItemDropsAllow") and (status.statusProperty("sbqDigestData") or {}).dropItem then
			world.sendEntityMessage(effect.sourceEntity(), "sbqDigestDrop", generateItemDrop({
				name = drop,
				count = config.getParameter("itemDropCount") or 1,
				parameters = config.getParameter("itemDropParams") or {}
			}))
		else
			local preyType = world.entityType(entity.id())
			if preyType ~= "monster" and entity.uniqueId() ~= nil then
				world.sendEntityMessage(effect.sourceEntity(), "sbqDigestStore", (status.statusProperty("sbqDigestData") or {}).location, entity.uniqueId(), generateItemDrop(root.assetJson("/sbqGeneral.config:npcEssenceTemplate")))
			end
		end
	end
end

function generateItemDrop(itemDrop)
	local itemDrop = itemDrop

	local predType = world.entityType(effect.sourceEntity())
	local preyType = world.entityType(entity.id())

	if predType == "npc" or predType == "player" then
		itemDrop.parameters.pred = world.entityName(effect.sourceEntity())
		itemDrop.parameters.predUUID = world.entityUniqueId(effect.sourceEntity())
	end
	if preyType == "npc" or preyType == "player" then
		itemDrop.parameters.prey = world.entityName(entity.id())
		itemDrop.parameters.preyUUID = world.entityUniqueId(entity.id())
		local identity
		if preyType == "npc" then
			identity = world.callScriptedEntity(entity.id(), "npc.humanoidIdentity")
		end
		local overrideData = getIdentity(entity.id(), identity)
		identity = overrideData.identity or {}
		local species = overrideData.species or world.entitySpecies(entity.id())
		local speciesFile = root.assetJson("/species/" .. species .. ".species")
		itemDrop.parameters.preySpecies = species
		itemDrop.parameters.preyDirectives = (overrideData.directives or "")..(identity.bodyDirectives or "")..(identity.hairDirectives or "")
		itemDrop.parameters.preyColorMap = speciesFile.baseColorMap
		identity.name = itemDrop.parameters.prey or ""
		itemDrop.parameters.npcArgs = {
			npcSpecies = overrideData.species,
			npcType = "generictenant",
			npcLevel = 1,
			npcParam = {
				wasPlayer = preyType == "player",
				identity = identity,
				scriptConfig = {
					uniqueId = itemDrop.parameters.preyUUID
				},
				statusControllerSettings = {
					statusProperties = {
						sbqPreyEnabled = status.statusProperty("sbqPreyEnabled")
					}
				}
			}
		}
		if preyType == "npc" then
			itemDrop.parameters.npcArgs.npcType = world.callScriptedEntity(entity.id(), "npc.npcType")
			itemDrop.parameters.npcArgs.npcLevel = world.callScriptedEntity(entity.id(), "npc.level")
			itemDrop.parameters.npcArgs.npcSeed = world.callScriptedEntity(entity.id(), "npc.seed")
			itemDrop.parameters.description = ((root.npcConfig(itemDrop.parameters.npcArgs.npcType) or {}).scriptConfig or {}).cardDesc or ""
		end
		itemDrop.parameters.tooltipKind = "filledcapturepod"
		itemDrop.parameters.tooltipFields = {
			subtitle = (itemDrop.parameters.npcArgs.npcParam.wasPlayer and "Player") or itemDrop.parameters.npcArgs.npcType or
				"generictenant",
			collarNameLabel = "",
			noCollarLabel = "",
		}
		itemDrop.parameters.portraitNpcParam = {
			items = {
				override = {
					{0,
						{
							{
							}
						}
					}
				}
			}
		}
		itemDrop.parameters.tooltipFields.objectImage =
			root.npcPortrait("full", itemDrop.parameters.npcArgs.npcSpecies,
				itemDrop.parameters.npcArgs.npcType or "generictenant",
			itemDrop.parameters.npcArgs.npcLevel or 1, itemDrop.parameters.npcArgs.npcSeed, sb.jsonMerge(itemDrop.parameters.npcArgs.npcParam, itemDrop.parameters.portraitNpcParam or {}))

		if itemDrop.parameters.pred then
			itemDrop.parameters.gurgledBy = config.getParameter("gurgledByText")
			itemDrop.parameters.tooltipFields.collarNameLabel = ( itemDrop.parameters.gurgledBy or "Gurgled by: ") .. itemDrop.parameters.pred
		end
		itemDrop.parameters.shortdescription = itemDrop.parameters.prey.."'s Essence"
		itemDrop.parameters.inventoryIcon = root.npcPortrait("bust", itemDrop.parameters.npcArgs.npcSpecies,
			itemDrop.parameters.npcArgs.npcType or "generictenant",
			itemDrop.parameters.npcArgs.npcLevel or 1, itemDrop.parameters.npcArgs.npcSeed,
			sb.jsonMerge(itemDrop.parameters.npcArgs.npcParam, itemDrop.parameters.portraitNpcParam or {}))
	end

	return itemDrop
end

function getPreyEnabled(setting)
	return sb.jsonMerge(root.assetJson("/sbqGeneral.config:defaultPreyEnabled")[world.entityType(entity.id())], sb.jsonMerge((status.statusProperty("sbqPreyEnabled") or {}), (status.statusProperty("sbqOverridePreyEnabled")or {})))[setting]
end
