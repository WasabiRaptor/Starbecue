

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

function doItemDrop()
	if self.dropItem and not self.droppedItem then
		self.droppedItem = true
		local drop = config.getParameter("itemDrop")
		if drop and getPreyEnabled(config.getParameter("digestType").."ItemDropsAllow") and (status.statusProperty("sbqDigestData") or {}).dropItem then
			world.sendEntityMessage(effect.sourceEntity(), "sbqDigestDrop", sbq.generateItemDrop(effect.sourceEntity(), config.getParameter("gurgledByText"), {
				name = drop,
				count = config.getParameter("itemDropCount") or 1,
				parameters = config.getParameter("itemDropParams") or {}
			}))
		else
			local preyType = world.entityType(entity.id())
			if preyType ~= "monster" and entity.uniqueId() ~= nil then
				world.sendEntityMessage(effect.sourceEntity(), "sbqDigestStore", (status.statusProperty("sbqDigestData") or {}).location, entity.uniqueId(), sbq.generateItemDrop(effect.sourceEntity(), config.getParameter("gurgledByText"), root.assetJson("/sbqGeneral.config:npcEssenceTemplate")))
			end
		end
	end
end

function getPreyEnabled(setting)
	return sb.jsonMerge(root.assetJson("/sbqGeneral.config:defaultPreyEnabled")[world.entityType(entity.id())], sb.jsonMerge((status.statusProperty("sbqPreyEnabled") or {}), (status.statusProperty("sbqOverridePreyEnabled")or {})))[setting]
end
