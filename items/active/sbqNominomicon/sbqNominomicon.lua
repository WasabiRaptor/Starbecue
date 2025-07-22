
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
			local entities = world.entityQuery( activeItem.ownerAimPosition(), 2, {
				withoutEntityId = entity.id(), includedTypes = { "vehicle", "npc", "object", "monster" }
			})
			if entities[1] ~= nil then
				getEntitySettingsMenu(entities, 1)
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
				player.queueUIMessage(sbq.getString(":targetOwned"))
				return animator.playSound("error")
			end
            player.interact("ScriptPane", { gui = {}, scripts = { "/metagui/sbq/build.lua" }, data = world.getObjectParameter(entities[i],"sbqConfigData"), ui = world.getObjectParameter(entities[i], "sbqConfigGui") }, entities[i])
			return
		end
	end
	if world.entityStatPositive(entities[i], "sbqIsPrey") then
		getEntitySettingsMenu(entities, i+1)
		return
	end
	sbq.addRPC(world.sendEntityMessage( entities[i], "sbqSettingsPageData", entity.uniqueId() ), function (data)
		if data then
			if (not player.isAdmin()) and data.parentEntityData[2] and not ((entity.uniqueId() == data.parentEntityData[1]) or (entity.uniqueId() == data.parentEntityData[2])) then
				player.queueUIMessage(sbq.getString(":targetOwned"))
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
