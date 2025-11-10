
sbq = {}

require("/scripts/any/SBQ_RPC_handling.lua")
require("/scripts/any/SBQ_util.lua")

function init()
	activeItem.setTwoHandedGrip(true)
	activeItem.setArmAngle(-45)
end

clicked = false

function update(dt, fireMode, shiftHeld, controls)
	if (fireMode == "primary" or fireMode == "alt") and not clicked then
		clicked = true
		if sbq.timer("menu", 1) then
			local entities = world.entityQuery( activeItem.ownerAimPosition(), 1, {
				withoutEntityId = entity.id(), includedTypes = { "vehicle", "npc", "object", "monster" }
			})
			if entities[1] ~= nil then
				if fireMode == "alt" then
					getEntitySettingsMenu(entities, 1)
				elseif fireMode == "primary" then
					getEntityHelpMenu(entities)
				end
			else
				if fireMode == "primary" then
					player.interact("ScriptPane", { gui = {}, scripts = { "/metagui/sbq/build.lua" }, ui = "starbecue:help" })
				end
			end
		end
	elseif fireMode == "none" then
		clicked = false
	end
	sbq.checkRPCsFinished(dt)
	sbq.checkTimers(dt)
end

function getEntitySettingsMenu(entities, i)
	if (not entities) or (not i) or (not entities[i]) or (not world.entityExists(entities[i])) then return end
	local entityType = world.entityType(entities[i])
	if entityType == "object" then
		if world.getObjectParameter(entities[i], "sbqConfigGui") then
			if world.getObjectParameter(entities[i], "sbqConfigOwnerOnly") and (world.getObjectParameter(entities[i], "owner") ~= player.uniqueId()) and not player.isAdmin() then
				interface.queueMessage(sbq.getString(":targetOwned"))
				return animator.playSound("error")
			end
			player.interact("ScriptPane", { gui = {}, scripts = { "/metagui/sbq/build.lua" }, data = world.getObjectParameter(entities[i],"sbqConfigData"), ui = world.getObjectParameter(entities[i], "sbqConfigGui") }, entities[i])
			return
		end
	end
	if world.entity(entities[i]):statPositive("sbqIsPrey") then
		getEntitySettingsMenu(entities, i+1)
		return
	end
	sbq.addRPC(world.sendEntityMessage( entities[i], "sbqSettingsPageData", entity.uniqueId() ), function (data)
		if data then
			if (not player.isAdmin()) and data.parentEntityData[2] and not ((entity.uniqueId() == data.parentEntityData[1]) or (entity.uniqueId() == data.parentEntityData[2])) then
				interface.queueMessage(sbq.getString(":targetOwned"))
				return animator.playSound("error")
			end
			player.interact("ScriptPane", { gui = {}, scripts = { "/metagui/sbq/build.lua" }, data = {sbq = data}, ui =  (data.ui or "starbecue:entitySettings") }, entities[i])
		else
			getEntitySettingsMenu(entities, i+1)
		end
	end, function()
		getEntitySettingsMenu(entities, i+1)
	end)
end

function getEntityHelpMenu(entities)
	for _, eid in ipairs(entities) do
		local entityMethods = world.entity(eid)
		local helpPage = entityMethods:getParameter("sbqHelpPage")
		if helpPage then
			player.interact("ScriptPane", { gui = {}, scripts = { "/metagui/sbq/build.lua" }, data = { helpPage = helpPage }, ui = "starbecue:help" })
			return
		end
	end
	player.interact("ScriptPane", { gui = {}, scripts = { "/metagui/sbq/build.lua" }, ui = "starbecue:help" })

end
