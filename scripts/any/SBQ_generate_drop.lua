require("/scripts/rect.lua")

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
		local identity = humanoid.getIdentity()
		local speciesFile = root.speciesConfig(identity.species)
		itemDrop.parameters.preySpecies = species
		itemDrop.parameters.preyDirectives = identity.bodyDirectives
		itemDrop.parameters.preyColorMap = speciesFile.baseColorMap
		itemDrop.parameters.npcArgs = {
			npcSpecies = identity.species,
			npcType = "generictenant",
			npcLevel = 1,
			npcParam = {
				wasPlayer = preyType == "player",
				identity = identity,
				scriptConfig = {
					uniqueId = itemDrop.parameters.preyUUID,
					sbqSettings = status.statusProperty("sbqSettings")
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

			local npcConfig = root.npcConfig(itemDrop.parameters.npcArgs.npcType)
			if npcConfig.scriptConfig.isOC then
				itemDrop.parameters.rarity = "rare"
			elseif npcConfig.scriptConfig.sbqNPC then
				itemDrop.parameters.rarity = "uncommon"
			end
		elseif preyType == "player" then
			itemDrop.parameters.rarity = "legendary"
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
