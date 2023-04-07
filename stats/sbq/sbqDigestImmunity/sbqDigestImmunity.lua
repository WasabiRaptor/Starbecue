
function init()
	message.setHandler("sbqRefreshDigestImmunities", function ()
		refresh()
		script.setUpdateDelta(0)
	end)
end

function update(dt)
	local position = entity.position()
	if (world ~= nil) and (world.regionActive ~= nil) and world.regionActive({position[1]-1,position[2]-1,position[1]+1,position[2]+1}) then
		refresh()
		script.setUpdateDelta(0)
	end
end

local groupId
function refresh(forceType)
	local preyEnabled = sb.jsonMerge(root.assetJson("/sbqGeneral.config:defaultPreyEnabled")[forceType or world.entityType(entity.id())], sb.jsonMerge((status.statusProperty("sbqPreyEnabled") or {}), (status.statusProperty("sbqOverridePreyEnabled")or {})))
	local statModifierGroup = {}
	if not preyEnabled.digestAllow then
		table.insert(statModifierGroup, {stat = "digestionImmunity", amount = 1})
	end
	if not preyEnabled.softDigestAllow then
		table.insert(statModifierGroup, {stat = "softDigestImmunity", amount = 1})
	end

	if not preyEnabled.cumDigestAllow then
		table.insert(statModifierGroup, {stat = "cumDigestImmunity", amount = 1})
	end
	if not preyEnabled.cumSoftDigestAllow then
		table.insert(statModifierGroup, {stat = "cumSoftDigestImmunity", amount = 1})
	end

	if not preyEnabled.femcumDigestAllow then
		table.insert(statModifierGroup, {stat = "femcumDigestImmunity", amount = 1})
	end
	if not preyEnabled.femcumSoftDigestAllow then
		table.insert(statModifierGroup, {stat = "femcumSoftDigestImmunity", amount = 1})
	end

	if not preyEnabled.milkDigestAllow then
		table.insert(statModifierGroup, {stat = "milkDigestImmunity", amount = 1})
	end
	if not preyEnabled.milkSoftDigestAllow then
		table.insert(statModifierGroup, {stat = "milkSoftDigestImmunity", amount = 1})
	end

	if not groupId then
		groupId = effect.addStatModifierGroup(statModifierGroup)
	else
		effect.setStatModifierGroup(groupId, statModifierGroup)
	end
end
