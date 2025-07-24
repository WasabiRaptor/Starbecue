
sbq = {}
require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/rect.lua"
require "/scripts/poly.lua"
require "/scripts/interp.lua"
require "/scripts/any/SBQ_RPC_handling.lua"
require "/items/active/sbqController/sbqControllerSetup.lua"
require "/scripts/any/SBQ_util.lua"


function init()
	sbq.config = root.assetJson("/sbq.config")
	sbq.strings = root.assetJson("/sbqStrings.config")
	sbq.gui = root.assetJson("/sbqGui.config")
	sbq.entityId = player.id

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
			sbq.logInfo(string.format("Attmpted invalid radial menu script: %s(%s)", script, sb.printJson({...})))
		end
    end)
end


function dontDoRadialMenu(arg)
	dontDoMenu = arg
end

local shiftHeldTime = 0
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
	world.sendEntityMessage(player.id(), "sbqQueueAction", "grabRelease")
	world.sendEntityMessage(player.id(), "sbqQueueAction", "rpActionReset")
end

function sbq.setAction(action)
	storage.action = action

	local icon, shortdescription, description = sbq.getActionData(action, (world.sendEntityMessage(player.id(), "sbqActionAvailable", storage.action):result() or {})[1], storage.iconDirectory)
	activeItem.setInventoryIcon(icon)
	activeItem.setShortDescription(shortdescription)
	activeItem.setDescription(description.."\n"..sbq.strings.controllerDescAppend)
end

function sbq.clickAction()
	if not storage.action then return false end
	local entityaimed = world.entityQuery(activeItem.ownerAimPosition(), sbq.config.actionRadius, {
		withoutEntityId = entity.id(),
		withoutEntityIds = sbq.entitiesLounging(player.id()),
		includedTypes = {"creature"}
	})

	world.sendEntityMessage(player.id(), "sbqTryAction", "rpActionReset")
	local bounds = mcontroller.collisionBoundBox()
	local paddedbounds = rect.pad(bounds, sbq.config.actionRange * mcontroller.getScale())
	local result
	for i, targetId in ipairs(entityaimed) do
		local targetBounds = world.entityCollisionBoundBox(targetId)
		if bounds and targetBounds and (rect.intersects(bounds, targetBounds) or ((entity.entityInSight(targetId)) and (rect.intersects(paddedbounds, targetBounds)))) then
			if sbq.isLoungeDismountable(targetId) then
				result = {sbq.attemptAction(targetId)}
				break
			end
		end
	end

    if result == nil then
        result = world.sendEntityMessage(player.id(), "sbqTryAction", storage.action):result() or {}
    end
    local success, failReason, time, successfulFail, failReason2 = table.unpack(result)

	if (not success) and (failReason ~= "targetMissing") then
		animator.playSound("error")
		interface.queueMessage(sbq.getString(":action_"..tostring(failReason)))
	end
	return table.unpack(result)
end

function sbq.attemptAction(targetId)
	if shiftHeldTime > 0 then
		local success, failReason = table.unpack(world.sendEntityMessage(player.id(), "sbqActionAvailable", storage.action, targetId):result() or {})
		if success then
			sbq.addRPC(world.sendEntityMessage(targetId, "sbqPromptAction", entity.id(), storage.action, true), function(response)
				if not response then return end
				local tryAction, isDom, line, action, target = table.unpack(response)
				if tryAction then
					world.sendEntityMessage(player.id(), "sbqTryAction", storage.action, targetId)
				end
			end)
		end
		return success, failReason
	else
		local targetSettings = sbq.getPublicProperty(targetId, "sbqPublicSettings") or {}
		if sbq.query(targetSettings, {"subBehavior", storage.action, "consentRequired"}) then return false, "consentRequired" end
		return table.unpack(world.sendEntityMessage(player.id(), "sbqTryAction", storage.action, targetId):result() or {})
	end
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
				messageTarget = player.id(),
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
	local occupants = sbq.entitiesLounging(player.id())
	local options = {
		{
			args = {"letout", false, storage.action},
			name = sbq.strings.letout,
			locked = (not occupants) or (not occupants[1]),
			description = sbq.strings.controllerLetOutAnyDesc,
			message = "sbqTryAction"
		},
		{
			args = { "open", "RoleplayMenu" },
			name = sbq.strings.controllerRPMenu,
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
		message = false
	}})
end

local AssignMenu = {}
RadialMenu.AssignMenu = AssignMenu
setmetatable(AssignMenu, _RadialMenu)
function AssignMenu:init()
	local options = {}

	for _, action in ipairs(world.sendEntityMessage(player.id(), "sbqActionList", "assign"):result() or {}) do
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
	local occupants = sbq.entitiesLounging(player.id())

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
	local options = {}

	for _, action in ipairs(world.sendEntityMessage(player.id(), "sbqActionList", "predRadialMenuSelect", entityId):result() or {}) do
		table.insert(options, {
			name = sbq.getString(action.name or (":" .. action.action)),
			args = { action.action, entityId, table.unpack(action.args or {}) },
			locked = not action.available,
			description = sbq.getString(action.description or (":" .. action.action.."Desc")),
			message = "sbqTryAction"
		})
	end
	if world.isMonster(entityId) or world.isNpc(entityId) then
		table.insert(options, ((#options >= 1) and 2) or 1, {
			name = sbq.strings.interact,
			args = {entityId},
			message = "sbqInteractWithEntity",
			description = sbq.strings.interactDesc
		})
	end

	self:openRadialMenu({ options = options, cancel = {
		args = {"open","OccupantsMenu"}
	}})
end

local RoleplayMenu = {}
RadialMenu.RoleplayMenu = RoleplayMenu
setmetatable(RoleplayMenu, _RadialMenu)
function RoleplayMenu:init()
	local options = {}

	for _, action in ipairs(world.sendEntityMessage(player.id(), "sbqActionList", "rp"):result() or {}) do
		table.insert(options, {
			name = sbq.getString(action.name or (":" .. action.action)),
			args = { action.action, nil, table.unpack(action.args or {}) },
			locked = not action.available,
			description = sbq.getString(action.description or (":" .. action.action.."Desc")),
			message = "sbqTryAction"
		})
	end
	self:openRadialMenu({ options = options, cancel = {
		args = {"open","TopMenu"}
	}})
end
