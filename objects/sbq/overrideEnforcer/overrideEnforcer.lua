local smash = true
sbq = {}
function init()
	sbq.config = root.assetJson("/sbq.config")
	if not entity.uniqueId() then
		object.setUniqueId(sb.makeUuid())
	end
	local enforcerUUID = world.getProperty("sbqOverrideEnforcerUUID")
	if enforcerUUID and (enforcerUUID ~= entity.uniqueId()) then return end
	smash = false
	world.setProperty("sbqOverrideEnforcerUUID", entity.uniqueId())
	world.setProperty("sbqOverrideSettings", sb.jsonMerge(sbq.config.serverOverrideSettings, config.getParameter("overrideSettings")))
	world.setProperty("sbqOverrideSettings_player", sb.jsonMerge(sbq.config.serverEntityTypeOverrideSettings.player, config.getParameter("overrideSettings_player")))
	world.setProperty("sbqOverrideSettings_npc", sb.jsonMerge(sbq.config.serverEntityTypeOverrideSettings.npc, config.getParameter("overrideSettings_npc")))
	world.setProperty("sbqOverrideSettings_object", sb.jsonMerge(sbq.config.serverEntityTypeOverrideSettings.object, config.getParameter("overrideSettings_object")))
	storage.ownerUUID = config.getParameter("ownerUUID") or storage.ownerUUID

	object.setInteractive(true)

	message.setHandler("sbqSetOwner", function(_, _, owner)
		storage.ownerUUID = config.getParameter("ownerUUID") or storage.ownerUUID or owner
	end)
	message.setHandler("sbqSmash", function(_, _)
		object.smash()
	end)

	message.setHandler("sbqSetWorldOverrideSettings", function (_,_, newStorage, global, player, npc, object)
		storage = newStorage
		object.setConfigParameter("overrideSettings", global)
		object.setConfigParameter("overrideSettings_player", player)
		object.setConfigParameter("overrideSettings_npc", npc)
		object.setConfigParameter("overrideSettings_object", object)

		world.setProperty("sbqOverrideSettings", sb.jsonMerge(sbq.config.serverOverrideSettings, global))
		world.setProperty("sbqOverrideSettings_player", sb.jsonMerge(sbq.config.serverEntityTypeOverrideSettings.player, player))
		world.setProperty("sbqOverrideSettings_npc", sb.jsonMerge(sbq.config.serverEntityTypeOverrideSettings.npc, npc))
		world.setProperty("sbqOverrideSettings_object", sb.jsonMerge(sbq.config.serverEntityTypeOverrideSettings.object, object))
	end)
end

function update()
	if smash then object.smash() end
	script.setUpdateDelta(0)
end

function onInteraction(args)
	return {"ScriptPane", { data = storage, gui = { }, scripts = {"/metagui/sbq/build.lua"}, ui = "starbecue:overrideEnforcer" }}
end

function die()
	storage.ownerUUID = nil
	local enforcerUUID = world.getProperty("sbqOverrideEnforcerUUID")
	if enforcerUUID == entity.uniqueId() then
		world.setProperty("sbqOverrideEnforcerUUID", nil)
		world.setProperty("sbqOverrideSettings", nil)
		world.setProperty("sbqOverrideSettings_player", nil)
		world.setProperty("sbqOverrideSettings_npc", nil)
		world.setProperty("sbqOverrideSettings_object", nil)

	end
end
