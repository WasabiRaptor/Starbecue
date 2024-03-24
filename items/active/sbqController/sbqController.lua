
sbq = {}
require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/rect.lua"
require "/scripts/poly.lua"
require "/scripts/interp.lua"
require "/scripts/any/SBQ_RPC_handling.lua"
require "/items/active/sbqController/sbqControllerSetup.lua"


function init()
	sbq.config = root.assetJson("/sbq.config")
	sbq.strings = root.assetJson("/sbqStrings.config")
	sbq.gui = root.assetJson("/sbqGui.config")


	activeItem.setHoldingItem(false)
	storage = storage or {}
	sbq.setAction(storage.action)

	message.setHandler("sbqControllerRotation", function(_, _, enabled)
		sbq.rotationEnabled = enabled
		activeItem.setHoldingItem(enabled)
		if not enabled then
			activeItem.setFacingDirection(0)
		end
	end)

	message.setHandler("sbqControllerRadialMenuScript", function(_, _, script, ...)
		if not script then return end
		if RadialMenu[script] then
			RadialMenu[script](RadialMenu, ...)
		else
			sb.logInfo(string.format("[%s] Attmpted invalid radial menu script: %s(%s)", entity.id(), script, sb.printJson({...})))
		end
	end)
end

function dontDoRadialMenu(arg)
	dontDoMenu = arg
end

local shiftHeldTime
function update(dt, fireMode, shiftHeld, controls)
	if shiftHeld then
		shiftHeldTime = shiftHeldTime + dt
	else
		shiftHeldTime = 0
	end
	sbq.checkRPCsFinished(dt)

	if RadialMenu.activeMenu then
		if shiftHeld then
			RadialMenu:update(dt, fireMode, shiftHeld, controls)
		else
			RadialMenu:close()
		end
	else
		if (shiftHeldTime) > 0.2 and controls.up then
			RadialMenu:open("TopMenu")
		elseif fireMode ~= "none" and not clicked and not RadialMenu.activeMenu then
			sbq.clickAction()
			clicked = true
		elseif fireMode == "none" then
			if sbq.rotationEnabled then
				sbq.aimAngle, sbq.aimDirection = activeItem.aimAngleAndDirection(0, activeItem.ownerAimPosition())
				activeItem.setArmAngle(sbq.aimAngle)
				activeItem.setFacingDirection(sbq.aimDirection)
			end
			clicked = false
		end
	end
end

function uninit()
	player.setScriptContext("starbecue")
	return player.callScript("sbq.tryAction", "grabRelease")
end

function sbq.setAction(action)
	storage.action = action
	player.setScriptContext("starbecue")
	local icon, shortdescription, description = sbq.getActionData(action, (player.callScript("sbq.actionAvailable", action) or {})[1], storage.iconDirectory)
	activeItem.setInventoryIcon(icon)
	activeItem.setFriendlyName(shortdescription)
	activeItem.setDescription(description.."\n"..sbq.strings.controllerDescAppend)
end

function sbq.clickAction()
	if not storage.action then return false end
	local entityaimed = world.entityQuery(activeItem.ownerAimPosition(), sbq.config.actionRadius, {
		withoutEntityId = entity.id(),
		withoutEntityIds = loungeable.entitiesLounging(),
		includedTypes = {"creature"}
	})
	player.setScriptContext("starbecue")
	local result
	for i, targetId in ipairs(entityaimed) do
		if entity.entityInSight(targetId) and ((sbq.config.actionRange * mcontroller.scale()) >= vec2.mag(entity.distanceToEntity(targetId))) then
			local loungeAnchor = world.entityCurrentLounge(targetId)
			if (not loungeAnchor) or loungeAnchor.dismountable then
				result = player.callScript("sbq.tryAction", storage.action, targetId)
				break
			end
		end
	end

	if result == nil then
		result = player.callScript("sbq.tryAction", storage.action)
	end
	if result and not result[1] and not (result[2] == "targetMissing") then
		animator.playSound("error")
	end
	-- sb.logInfo(string.format("[%s] Action results: %s:%s", entity.id(), storage.action, sb.printJson(result)))
	return table.unpack(result or {false})
end

RadialMenu = {}
setmetatable(RadialMenu, _RadialMenu)
function RadialMenu:open(menuName, ...)
	if self.activeMenu then
		self.activeMenu:uninit()
	end
	if self[menuName] and self[menuName].isMenu then
		self.activeMenuName = menuName
		self.activeMenu = self[menuName]
		self.activeMenu:init(...)
		setmetatable(self, { __index = self.activeMenu })
	else
		sb.logInfo(string.format("[%s] no radial menu named: %s", entity.id(), menuName))
	end
end
function RadialMenu:close()
	if self.activeMenu then
		self.activeMenu:uninit()
	end
	self.activeMenuName = nil
	self.activeMenu = nil
	player.interact("ScriptPane", {baseConfig = "/interface/scripted/sbq/close/sbqClose.config"}, player.id())
end

_RadialMenu = {isMenu = true}
_RadialMenu.__index = _RadialMenu
function _RadialMenu:init()
end
function _RadialMenu:update()
end
function _RadialMenu:uninit()
end
function _RadialMenu:openRadialMenu(overrides)
	player.interact("ScriptPane", sb.jsonMerge(
		{
			baseConfig = "/interface/scripted/sbq/radialMenu/sbqRadialMenu.config",
			default = {
				context = "starbecue",
				message = "sbqControllerRadialMenuScript"
			},
			cancel = {}
		},
		overrides
	), player.id())
end

function _RadialMenu:controllerAssign(action)
	sbq.setAction(action)
end

local TopMenu = {}
RadialMenu.TopMenu = TopMenu
setmetatable(TopMenu, _RadialMenu)
function TopMenu:init()
	local occupants = loungeable.entitiesLounging()
	local options = {
		{
			args = {"letout", false, storage.action},
			name = sbq.strings.letout,
			locked = (not occupants) or (not occupants[1]),
			description = sbq.strings.controllerLetOutAnyDesc,
			script = "sbq.tryAction"
		},
		{
			args = { "open", "OccupantsMenu" },
			name = sbq.strings.controllerRPMenu,
			locked = true,
			description = sbq.strings.controllerRPMenuDesc
		},
		{
			args = {"open","OccupantsMenu"},
			name = sbq.strings.occupants,
			locked = (not occupants) or (not occupants[1]),
			description = sbq.strings.controllerOccupantsDesc

		},
		{
			args = {"open","AssignMenu"},
			name = sbq.strings.controllerAssign,
			description = sbq.strings.controllerAssignDesc
		}
	}
	self:openRadialMenu({ options = options, cancel = {
		script = false,
		message = false
	}})
end

local AssignMenu = {}
RadialMenu.AssignMenu = AssignMenu
setmetatable(AssignMenu, _RadialMenu)
function AssignMenu:init()
	local options = {}
	player.setScriptContext("starbecue")
	for _, action in ipairs(player.callScript("sbq.actionList", "assign") or {}) do
		local icon, shortdescription, description = sbq.getActionData(action.action, true, storage.iconDirectory)
		table.insert(options, {
			args = {"controllerAssign", action.action},
			name = shortdescription,
			icon = icon,
			locked = not action.available,
			description = description
		})
	end
	self:openRadialMenu({ options = options, cancel = {
		args = {"open","TopMenu"}
	}})
end

local OccupantsMenu = {}
RadialMenu.OccupantsMenu = OccupantsMenu
setmetatable(OccupantsMenu, _RadialMenu)
function OccupantsMenu:init()
	local options = {}
	local occupants = loungeable.entitiesLounging()

	for _, entityId in ipairs(occupants) do
		table.insert(options, {
			args = {"open", "SelectedOccupantMenu", entityId},
			name = world.entityName(entityId),
			icon = world.entityPortrait(entityId, "bust")
		})
	end
	self:openRadialMenu({ options = options, cancel = {
		args = {"open","TopMenu"},
	}})
end

local SelectedOccupantMenu = {}
RadialMenu.SelectedOccupantMenu = SelectedOccupantMenu
setmetatable(SelectedOccupantMenu, _RadialMenu)
function SelectedOccupantMenu:init(entityId)
	local options = {
		{
			args = {"letout", entityId, storage.action},
			name = sbq.strings.letout,
			description = sbq.strings.controllerLetOutSelectedDesc,
			locked = not player.callScript("sbq.actionAvailable", "letout", entityId),
			script = "sbq.tryAction"
		}
	}
	if world.isMonster(entityId) or world.isNpc(entityId) then
		table.insert(options, {
			name = sbq.strings.interact,
			args = {entityId},
			script = "player.interactWithEntity",
			description = sbq.strings.interactDesc
		})
	end
	player.setScriptContext("starbecue")
	for _, action in ipairs(player.callScript("sbq.actionList", "predRadialMenuSelect", entityId) or {}) do
		local icon, shortdescription, description = sbq.getActionData(action.action, action.available, storage.iconDirectory, true)
		table.insert(options, {
			name = shortdescription,
			args = { action.action, entityId, table.unpack(action.args or {}) },
			locked = not action.available,
			icon = icon,
			description = description,
			script = "sbq.tryAction"
		})
	end

	self:openRadialMenu({ options = options, cancel = {
		args = {"open","OccupantsMenu"}
	}})
end
