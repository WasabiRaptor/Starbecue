
sbq = {}

require("/scripts/any/SBQ_RPC_handling.lua")

function init()
	activeItem.setTwoHandedGrip(true)
	activeItem.setArmAngle(-45)
end

clicked = false

function update(dt, fireMode, shiftHeld, controls)
	if (fireMode == "primary" or fireMode == "alt") and not clicked then
		clicked = true
		if sbq.timer("menu", 1) then
			local predators = world.entityQuery( activeItem.ownerAimPosition(), 2, {
				withoutEntityId = entity.id(), includedTypes = { "vehicle", "npc", "object" }
			})

			if predators[1] ~= nil then
				getEntitySettingsMenu(predators, 1)
			end
		end
	elseif fireMode == "none" then
		clicked = false
	end
	sbq.checkRPCsFinished(dt)
	sbq.checkTimers(dt)
end

function getEntitySettingsMenu(entities, i)
	if (not entities) or (not i) or (not entities[i]) or ((type(i) == "number" and type(entities[i]) == "number") and not world.entityExists(entities[i])) then return end
	sbq.addRPC(world.sendEntityMessage( entities[i], "getEntitySettingsMenuData", entity.uniqueId() ), function (data)
		if data then
			player.interact("ScriptPane", sb.jsonMerge({ gui = {}, scripts = { "/metagui/sbq/build.lua" }, ui =  ("starbecue:nominomicon") }, data), data.parent or player.id())
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
