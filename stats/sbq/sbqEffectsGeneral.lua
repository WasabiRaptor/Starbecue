

sbq = {}

function removeOtherBellyEffects()
	local name = config.getParameter("effect")
	local bellyEffectList = root.assetJson("/sbqGeneral.config").bellyStatusEffects
	for _, effect in ipairs(bellyEffectList) do
		if effect ~= name then
			status.removeEphemeralEffect(effect)
		end
	end
end
require("/scripts/SBQ_generate_drop.lua")
require("/scripts/SBQ_RPC_handling.lua")

function doItemDrop()
	if self.dropItem and not self.droppedItem then
		self.droppedItem = true
		local drop = config.getParameter("itemDrop")
		local digestData = (status.statusProperty("sbqDigestData") or {})
		if drop and getPreyEnabled(config.getParameter("digestType").."ItemDropsAllow") and digestData.dropItem then
			world.sendEntityMessage(effect.sourceEntity(), "sbqDigestDrop", sbq.generateItemDrop(effect.sourceEntity(), config.getParameter("gurgledByText"), {
				name = drop,
				count = config.getParameter("itemDropCount") or 1,
				parameters = config.getParameter("itemDropParams") or {}
			}))
		elseif entity.uniqueId() ~= nil then
			local doAbsorb = false
			local preyType = world.entityType(entity.id())
			if preyType == "npc" then
				local npcConfig = root.npcConfig(world.callScriptedEntity(entity.id(), "npc.npcType"))
				if npcConfig.scriptConfig.isOC then
					if digestData.absorbOCs then
						doAbsorb = true
					end
				elseif npcConfig.scriptConfig.sbqNPC then
					if digestData.absorbSBQNPCs then
						doAbsorb = true
					end
				else
					if digestData.absorbOthers then
						doAbsorb = true
					end
				end
			elseif preyType == "player" then
				if digestData.absorbPlayers then
					doAbsorb = true
				end
			end
			if doAbsorb then
				world.sendEntityMessage(effect.sourceEntity(), "sbqDigestStore", (status.statusProperty("sbqDigestData") or {}).location, entity.uniqueId(), sbq.generateItemDrop(effect.sourceEntity(), config.getParameter("gurgledByText"), root.assetJson("/sbqGeneral.config:npcEssenceTemplate")))
			end
		end
	end
end

function getPreyEnabled(setting)
	return sb.jsonMerge(root.assetJson("/sbqGeneral.config:defaultPreyEnabled")[world.entityType(entity.id())], sb.jsonMerge((status.statusProperty("sbqPreyEnabled") or {}), (status.statusProperty("sbqOverridePreyEnabled")or {})))[setting]
end
