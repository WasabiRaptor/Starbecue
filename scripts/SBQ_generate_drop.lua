require("/items/active/sbqTransformation/sbqDuplicatePotion/sbqGetIdentity.lua")

function sbq.generateItemDrop(pred, flavorText, itemDrop)
	local itemDrop = itemDrop

	local predType = world.entityType(pred)
	local preyType = world.entityType(entity.id())

	if predType == "npc" or predType == "player" then
		itemDrop.parameters.pred = world.entityName(pred)
		itemDrop.parameters.predUUID = world.entityUniqueId(pred)
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
		local boundRectSize = rect.size(mcontroller.boundBox())
		itemDrop.parameters.preySize = math.sqrt(boundRectSize[1] * boundRectSize[2])/root.assetJson("/sbqGeneral.config:size") -- size is being based on the player, 1 prey would be math.sqrt(1.4x3.72) as that is the bound rect of the humanoid hitbox

		itemDrop.parameters.tooltipFields.objectImage = root.npcPortrait(
			"full",
			itemDrop.parameters.npcArgs.npcSpecies,
			itemDrop.parameters.npcArgs.npcType or "generictenant",
			itemDrop.parameters.npcArgs.npcLevel or 1,
			itemDrop.parameters.npcArgs.npcSeed,
			sb.jsonMerge(itemDrop.parameters.npcArgs.npcParam,
			itemDrop.parameters.portraitNpcParam or {})
		)

		if itemDrop.parameters.pred then
			itemDrop.parameters.gurgledBy = flavorText
			itemDrop.parameters.tooltipFields.collarNameLabel = ( itemDrop.parameters.gurgledBy or "Gurgled by: ") .. itemDrop.parameters.pred
		end
		itemDrop.parameters.shortdescription = itemDrop.parameters.prey.."'s Essence"
		itemDrop.parameters.inventoryIcon = root.npcPortrait(
			"bust",
			itemDrop.parameters.npcArgs.npcSpecies,
			itemDrop.parameters.npcArgs.npcType or "generictenant",
			itemDrop.parameters.npcArgs.npcLevel or 1,
			itemDrop.parameters.npcArgs.npcSeed,
			sb.jsonMerge(itemDrop.parameters.npcArgs.npcParam, itemDrop.parameters.portraitNpcParam or {})
		)
	end

	return itemDrop
end
