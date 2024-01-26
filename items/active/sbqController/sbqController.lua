
sbq = {}

require("/scripts/SBQ_RPC_handling.lua")
require("/scripts/SBQ_species_config.lua")
require("/interface/scripted/sbq/sbqIndicatorHud/hudActions.lua")

function init()
	sbq.config = root.assetJson("/sbqGeneral.config")
	activeItem.setHoldingItem(false)
	local hand = activeItem.hand()
	if storage.clickAction == nil then
		storage.clickAction = "unassigned"
		storage.directives = ""
	end
	setIconAndDescription()

	message.setHandler( hand.."ItemData", function(_,_, data)
		storage.directives = data.directives or storage.directives or ""
		if data.assignClickAction ~= nil then
			storage.icon = data.icon
			storage.clickAction = data.assignClickAction
			setIconAndDescription()
		elseif ((not storage.clickAction) or (storage.clickAction == "unassigned")) and data.defaultClickAction ~= nil then
			activeItem.setInventoryIcon((data.defaultIcon or ("/items/active/sbqController/"..data.defaultClickAction..".png"))..(storage.directives or ""))
		else
			setIconAndDescription()
		end
	end)
end

local assignedMenu
local occupantsWhenAssigned
local selectedPrey
local selectedPreyIndex

function dontDoRadialMenu(arg)
	dontDoMenu = arg
end

function update(dt, fireMode, shiftHeld, controls)
	sbq.checkRPCsFinished(dt)
	if not player.isLounging() then
		sbq.sbqCurrentData = player.getProperty( "sbqCurrentData") or {}
		if occupantsWhenAssigned ~= (sbq.sbqCurrentData.totalOccupants or 0) then
			assignedMenu = nil
		end

		if (storage.seatdata.shift or 0) > 0.2 then
			if not assignedMenu and controls.up then
				if activeItem.hand() == "primary" then activeItem.callOtherHandScript("dontDoRadialMenu", true) end
				if dontDoMenu then return end
				assignedMenu = true
				selectedPrey = nil
				assignSelectMenu()

			elseif assignedMenu then
				if dontDoMenu then return end
				sbq.loopedMessage("radialSelection", player.id(), "sbqGetRadialSelection", {}, function(data)
					if data.selection ~= nil then
						sbq.lastRadialSelection = data.selection
						sbq.radialSelectionType = data.type
						if data.selection == "cancel" then return end
						if data.selection == "despawn" and data.pressed and not sbq.click then
							sbq.click = true
							sbq.letout(selectedPrey)
							return
						end

						if data.type == "controllerActionSelect" then
							if data.button == 0 and data.pressed and not sbq.click then
								sbq.click = true
								world.sendEntityMessage(player.id(), "primaryItemData", { assignClickAction = data.selection })
							elseif data.button == 2 and data.pressed and not sbq.click then
								sbq.click = true
								world.sendEntityMessage(player.id(), "altItemData", {assignClickAction = data.selection })
							end
						elseif data.type == "controllerSelectMenu" then
							if data.pressed and not sbq.click then
								sbq.click = true
								if data.selection == "assignAction" then
									assignAssignActionMenu()
								elseif data.selection == "rpAction" then
									assignRPActionMenu()
								elseif data.selection == "preyAction" then
									assignPreyActionMenu()
								end
							end
						elseif data.type == "controllerLocationSelect" then
							if data.pressed and not sbq.click then
								sbq.click = true
								assignLocationActionSelect(data)
							end
						elseif data.type == "controllerLocationPreyAction" then
							if data.pressed and not sbq.click then
								sbq.click = true
								locationPreyAction(data)
							end
						elseif data.type == "controllerPreySelect" then
							if data.pressed and not sbq.click then
								sbq.click = true
								assignPreyActionsLocation(data.selection)
							end
						elseif data.type == "controllerPreyAction" then
							if data.pressed and not sbq.click then
								sbq.click = true
								if type(sbq[data.selection]) == "function" then
									sbq[data.selection](selectedPrey, selectedPreyIndex, data.data)
								end
							end
						end
						if not data.pressed then
							sbq.click = false
						end
					end
				end)
			end
		elseif assignedMenu then
			world.sendEntityMessage( player.id(), "sbqOpenInterface", "sbqClose" )
			if sbq.lastRadialSelection == "despawn" then
				sbq.letout(selectedPrey)
			end
			assignedMenu = nil
			activeItem.callOtherHandScript("dontDoRadialMenu")
		else
			if fireMode == "primary" and not clicked then
				clicked = true
				doVoreAction()
			elseif fireMode == "none" then
				clicked = false
			end
		end
	end
end

function sbq.letout(i)
	if type(sbq.sbqCurrentData.id) == "number" and world.entityExists(sbq.sbqCurrentData.id) then
		if (sbq.sbqCurrentData.totalOccupants or 0) > 0 then
			world.sendEntityMessage(sbq.sbqCurrentData.id, "letout",i)
		else
			world.sendEntityMessage(sbq.sbqCurrentData.id, "despawn",i)
		end
	end
end

function assignAssignActionMenu()
	local sbqSettings = player.getProperty("sbqSettings") or {}
	local settings = sb.jsonMerge(sbqSettings.sbqOccupantHolder or {}, sbqSettings.global or {})

	local options = {
		{
			name = "despawn",
			icon = "/interface/xhover.png",
			title = "Let Out"
		},
		{
			name = "oralVore",
			icon = returnVoreIcon("oralVore") or "/items/active/sbqController/oralVore.png"
		},
		{
			name = "analVore",
			icon = returnVoreIcon("analVore") or "/items/active/sbqController/analVore.png"
		}
	}
	occupantsWhenAssigned = sbq.sbqCurrentData.totalOccupants or 0
	if (sbq.sbqCurrentData.totalOccupants or 0) > 0 then
		options[1].icon = nil
	end
	if settings.tailMaw then
		table.insert(options, 3, {
			name = "tailVore",
			icon = returnVoreIcon("tailVore") or "/items/active/sbqController/tailVore.png"
		} )
	end
	if settings.navel then
		table.insert(options, {
			name = "navelVore",
			icon = returnVoreIcon("navelVore") or "/items/active/sbqController/navelVore.png"
		} )
	end
	if settings.breasts then
		table.insert(options, {
			name = "breastVore",
			icon = returnVoreIcon("breastVore") or "/items/active/sbqController/breastVore.png"
		} )
	end
	if settings.pussy then
		table.insert(options, {
			name = "unbirth",
			icon = returnVoreIcon("unbirth") or "/items/active/sbqController/unbirth.png"
		} )
	end
	if settings.penis then
		table.insert(options, {
			name = "cockVore",
			icon = returnVoreIcon("cockVore") or "/items/active/sbqController/cockVore.png"
		} )
	end

	world.sendEntityMessage( player.id(), "sbqOpenInterface", "sbqRadialMenu", {options = options, type = "controllerActionSelect" })
end

function assignSelectMenu()
	local options = {
		{
			name = "despawn",
			icon = "/interface/xhover.png",
			title = "Let Out"
		},
		--[[{
			name = "rpAction",
			title = "Roleplay\nActions"
		},]]
		{
			name = "assignAction",
			title = "Assign\nClick"
		}
	}
	occupantsWhenAssigned = sbq.sbqCurrentData.totalOccupants or 0
	if (sbq.sbqCurrentData.totalOccupants or 0) > 0 then
		options[1].icon = nil
		table.insert(options, {
			name = "preyAction",
			title = "Prey\nActions"
		})
	end
	world.sendEntityMessage( player.id(), "sbqOpenInterface", "sbqRadialMenu", {options = options, type = "controllerSelectMenu" } )
end

function assignRPActionMenu()

end

function assignPreyActionMenu()
	local options = {
		{
			name = "all",
			title = "By Location"
		}
	}
	if sbq.sbqCurrentData.id and world.entityExists(sbq.sbqCurrentData.id) then
		sbq.addRPC(world.sendEntityMessage(sbq.sbqCurrentData.id, "getOccupancyData"), function (data)
			for i = 0, 7 do
				local number = i
				local i = tostring(i)
				if data.occupant and data.occupant[i].id ~= nil and world.entityExists(data.occupant[i].id) then
					table.insert(options, {
						name = data.occupant[i].id,
						title = (number+1)..": "..(world.entityName(data.occupant[i].id) or "")
					})
				end
			end
			world.sendEntityMessage( player.id(), "sbqOpenInterface", "sbqRadialMenu", {options = options, type = "controllerPreySelect" } )
		end)
	end
end

local locationAction

function assignLocationActionSelect(data)
	local options = {
		{
			name = "letout",
			title = "Let Out"
		}
	}
	local sbqSettings = player.getProperty("sbqSettings") or {}
	local settings = sb.jsonMerge(sbqSettings.sbqOccupantHolder or {}, sbqSettings.global or {})
	sbq.getSpeciesConfig(player.species(), settings)
	local sbqData = sbq.speciesConfig.sbqData

	locationAction = data.selection

	local locationData = sbqData.locations[data.selection]
	for j, action in ipairs(locationData.preyActions or {}) do
		if (not action.single) and sbq.checkSettings(action.checkSettings, settings) then
			table.insert(options, {
				name = action.script,
				title = action.name,
				data = action.args
			})
		end
	end

	world.sendEntityMessage( player.id(), "sbqOpenInterface", "sbqRadialMenu", {options = options, type = "controllerLocationPreyAction" } )
end

function locationPreyAction(selectionData)
	if sbq.sbqCurrentData.id and world.entityExists(sbq.sbqCurrentData.id) then
		sbq.addRPC(world.sendEntityMessage(sbq.sbqCurrentData.id, "getOccupancyData"), function(data)

			for i = 0, 7 do
				local number = i
				local i = tostring(i)
				if data.occupant and data.occupant[i].id ~= nil and world.entityExists(data.occupant[i].id) and
					data.occupant[i].location == locationAction then
					if type(sbq[selectionData.selection]) == "function" then
						sbq[selectionData.selection](data.occupant[i].id, number, selectionData.data)
					end
				end
			end
		end)
	end
end

function assignLocationSelect(data, sbqSettings, settings, sbqData)
	local options = {
	}
	local locations = {

	}
	for i = 0, 7 do
		local number = i
		local i = tostring(i)
		selectedPreyIndex = i
		if data.occupant and data.occupant[i].id ~= nil and world.entityExists(data.occupant[i].id) and
			(data.occupant[i].location ~= nil) and (data.occupant[i].location ~= "escaping") then
			locations[data.occupant[i].location] = (locations[data.occupant[i].location] or 0) + 1
		end
	end
	for name, count in pairs(locations) do
		table.insert(options, {
			name = name,
			title = sbqData.locations[name].name..": "..count
		})
	end
	if options[1] ~= nil then
		if #options == 1 then
			locationAction = options[1].name
			assignLocationActionSelect({selection = options[1].name})
		else
			world.sendEntityMessage( player.id(), "sbqOpenInterface", "sbqRadialMenu", {options = options, type = "controllerLocationSelect" } )

		end
	end
end

function assignPreyActionsLocation(id)
	selectedPrey = id
	local sbqSettings = player.getProperty("sbqSettings") or {}
	local settings = sb.jsonMerge(sbqSettings.sbqOccupantHolder or {}, sbqSettings.global or {})
	sbq.getSpeciesConfig(player.species(), settings)
	local sbqData = sbq.speciesConfig.sbqData

	local options = {
		{
			name = "despawn",
			title = "Let Out"
		},
		{
			name = "npcInteract",
			title = "Interact"
		}
	}
	if sbq.sbqCurrentData.id and world.entityExists(sbq.sbqCurrentData.id) then
		sbq.addRPC(world.sendEntityMessage(sbq.sbqCurrentData.id, "getOccupancyData"), function(data)
			sbq.occupant = data.occupant

			if id == "all" then
				assignLocationSelect(data, sbqSettings, settings, sbqData)
				return
			end


			for i = 0, 7 do
				local number = i
				local i = tostring(i)
				selectedPreyIndex = i
				if data.occupant and data.occupant[i].id ~= nil and world.entityExists(data.occupant[i].id) and data.occupant[i].id == id then
					local locationData = sbqData.locations[data.occupant[i].location]
					for j, action in ipairs(locationData.preyActions or {}) do
						if sbq.checkSettings(action.checkSettings, settings) then
							table.insert(options, {
								name = action.script,
								title = action.name,
								data = action.args
							})
						end
					end
					world.sendEntityMessage( player.id(), "sbqOpenInterface", "sbqRadialMenu", {options = options, type = "controllerPreyAction" } )
					break
				end
			end
		end)
	end
end

function doVoreAction(id)
	local withoutEntityIds = loungeable.entitiesLounging()
	local entityaimed = world.entityQuery(activeItem.ownerAimPosition(), 2, {
		withoutEntityId = entity.id(),
		withoutEntityIds = withoutEntityIds,
		includedTypes = {"creature"}
	})
	local entityInRange = world.entityQuery(mcontroller.position(), 5, {
		withoutEntityId = entity.id(),
		withoutEntityIds = withoutEntityIds,
		includedTypes = {"creature"}
	})
	for i, targetId in ipairs(entityaimed) do
		for j, eid in ipairs(entityInRange) do
			if targetId == eid and entity.entityInSight(targetId) then
				local loungeAnchor = world.entityLoungingIn(targetId)
				if (not loungeAnchor) or loungeAnchor.dismountable then
					world.sendEntityMessage(entity.id(), "sbqTryAction", storage.clickAction, targetId, {})
					return
				end
			end
		end
	end
	world.sendEntityMessage(entity.id(), "sbqTryAction", storage.clickAction, nil, {})
end


function setIconAndDescription()
	getDirectives()
	activeItem.setInventoryIcon((storage.icon or returnVoreIcon(storage.clickAction) or ("/items/active/sbqController/"..storage.clickAction..".png"))..(storage.directives or ""))
end

function returnVoreIcon(action)
	sbq.sbqCurrentData = player.getProperty( "sbqCurrentData") or {}
	if sbq.sbqCurrentData.species == "sbqOccupantHolder" or not sbq.sbqCurrentData.species then
		return (root.speciesConfig(humanoid.species()).voreIcons or {})[action]
	end
end

function getDirectives()
	sbq.sbqCurrentData = player.getProperty( "sbqCurrentData") or {}
	if sbq.sbqCurrentData.species == "sbqOccupantHolder" or not sbq.sbqCurrentData.species then
		storage.directives = humanoid.getIdentity().bodyDirectives
	end
end

require("/scripts/SBQ_check_settings.lua")
