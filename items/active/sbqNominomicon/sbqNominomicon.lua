
sbq = {}

require("/scripts/SBQ_RPC_handling.lua")

function init()
	activeItem.setTwoHandedGrip(true)
	activeItem.setArmAngle(-45)
end

function update(dt, fireMode, shiftHeld, controls)
	if fireMode == "primary" or fireMode == "alt" and not clicked then
		clicked = true

		local predators = world.entityQuery( activeItem.ownerAimPosition(), 2, {
			withoutEntityId = entity.id(), includedTypes = { "vehicle", "npc", "object" }
		})

		if predators[1] ~= nil then
			getEntitySettingsMenu(predators, 1)
		end
	elseif fireMode == "none" then
		clicked = false
	end
	sbq.checkRPCsFinished(dt)
end

function getEntitySettingsMenu(entities, i)
	sbq.addRPC(world.sendEntityMessage( entities[i], "getEntitySettingsMenuData", entity.uniqueId() ), function (data)
		if data then
			player.interact("ScriptPane",
				{ data = data, gui = {}, scripts = { "/metagui/sbq/build.lua" }, ui = "starbecue:" .. (data.ui or "nominomicon") }, data.parent or entities[i])
		else
			if entities[i+1] then
				getEntitySettingsMenu(entities, i+1)
			end
		end
	end, function()
		if entities[i+1] then
			getEntitySettingsMenu(entities, i+1)
		end
	end)
end
