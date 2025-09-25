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

	local imagePath = player.humanoidIdentity().imagePath

	storage.iconDirectories = {
		"/humanoid/" .. player.species() .. "/",
		"/humanoid/any/sbqActionIcons/"
	}
	if imagePath and (imagePath ~= "") then
		table.insert(storage.iconDirectories, 1, "/humanoid/" .. imagePath .. "/")
	end

	activeItem.setHoldingItem(false)
	storage = storage or {}
	sbq.setAction("primary", storage.actions.primary)

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
			sbq.logInfo(string.format("Attmpted invalid radial menu script: %s(%s)", script, sb.printJson({ ... })))
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
			sbq.clickAction(fireMode)
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

function sbq.setAction(fireMode, action)
	storage.actions[fireMode] = action

	local icon, shortdescription, description = sbq.getActionData(storage.actions.primary,
		(world.sendEntityMessage(player.id(), "sbqActionAvailable", storage.actions.primary):result() or {})[1],
		storage.iconDirectories)
	local icon2, shortdescription2, description2 = sbq.getActionData(storage.actions.alt,
		(world.sendEntityMessage(player.id(), "sbqActionAvailable", storage.actions.alt):result() or {})[1],
		storage.iconDirectories)

	activeItem.setInventoryIcon(icon or "/humanoid/any/sbqActionIcons/unassigned.png")
	activeItem.setSecondaryIcon(icon2 or "/humanoid/any/sbqActionIcons/unassigned.png")
	activeItem.setShortDescription(shortdescription or "SBQ Controller")
	activeItem.setDescription(sbq.getString(":controllerDescFormat"):format(description, description2))
end

function sbq.clickAction(fireMode)
	local action = storage.actions[fireMode]
	if (not action) or (action == "unassigned") then
		animator.playSound("error")
		interface.queueMessage(sbq.getString(":action_unassigned"))
		return false
	end
	local entityaimed = world.entityQuery(activeItem.ownerAimPosition(), sbq.config.actionRadius, {
		withoutEntityId = entity.id(),
		withoutEntityIds = world.loungingEntities(player.id()),
		includedTypes = { "creature" }
	})

	world.sendEntityMessage(player.id(), "sbqQueueAction", "rpActionReset")
	local bounds = mcontroller.collisionBoundBox()
	local paddedbounds = rect.pad(bounds, sbq.config.actionRange * mcontroller.getScale())
	local result
	for i, targetId in ipairs(entityaimed) do
		local targetBounds = world.entity(targetId):collisionBoundBox()
		if bounds and targetBounds and
			(
				rect.intersects(bounds, targetBounds)
				or (
					(entity.entityInSight(targetId))
					and (rect.intersects(paddedbounds, targetBounds))
				)
			) then
			if sbq.isLoungeDismountable(targetId) then
				result = { sbq.attemptAction(action, targetId) }
				break
			end
		end
	end

	if result == nil then
		result = world.sendEntityMessage(player.id(), "sbqTryAction", action):result()
	end
	local success, failReason, time, successfulFail, failReason2 = table.unpack(result or { false, "messageNotHandled" })

	if (not success) and (failReason ~= "targetMissing") then
		animator.playSound("error")
		interface.queueMessage(sbq.getString(":action_" .. tostring(failReason)))
	end
	return table.unpack(result)
end

function sbq.attemptAction(action, targetId)
	if shiftHeldTime > 0 then
		local success, failReason = table.unpack(world.sendEntityMessage(player.id(), "sbqActionAvailable",
			action,
			targetId):result() or {})
		if success then
			sbq.addRPC(world.sendEntityMessage(targetId, "sbqPromptAction", entity.id(), action, true),
				function(response)
					if response then sbq.addRPC(world.sendEntityMessage(player.id(), "sbqPromptResponse", table.unpack(response)), sbq.requestResults) end
				end)
		end
		return success, failReason
	else
		local targetSettings = sbq.getPublicProperty(targetId, "sbqPublicSettings") or {}
		if sbq.query(targetSettings, { "subBehavior", action, "consentRequired" }) then
			return false,
				"consentRequired"
		end
		return table.unpack(world.sendEntityMessage(player.id(), "sbqTryAction", action, targetId):result() or {})
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
	player.interact("ScriptPane", { baseConfig = "/interface/scripted/sbq/close/sbqClose.config" }, player.id())
end

_RadialMenu = { isMenu = true }
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
				onDown = true,
				messageTarget = player.id(),
				message = "sbqControllerRadialMenuScript"
			},
			cancel = {}
		},
		overrides
	), player.id())
end

function _RadialMenu:controllerAssign(action, position, mouseButton, isButtonDown)
	if mouseButton == 0 then
		sbq.setAction("primary", action)
	elseif mouseButton == 2 then
		sbq.setAction("alt", action)
	end
end

local TopMenu = {}
RadialMenu.TopMenu = TopMenu
setmetatable(TopMenu, _RadialMenu)
function TopMenu:init()
	local occupants = world.loungingEntities(player.id())
	local options = {
		{
			args = { "letout", false, {storage.actions.primary, storage.actions.alt} },
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
			args = { "open", "OccupantsMenu" },
			name = sbq.strings.occupants,
			locked = (not occupants) or (not occupants[1]),
			description = sbq.strings.controllerOccupantsDesc

		},
		{
			args = { "open", "AssignMenu" },
			name = sbq.strings.controllerAssign,
			description = sbq.strings.controllerAssignDesc
		}
	}
	self:openRadialMenu({
		options = options,
		cancel = {
			message = false
		}
	})
end

local AssignMenu = {}
RadialMenu.AssignMenu = AssignMenu
setmetatable(AssignMenu, _RadialMenu)
function AssignMenu:init()
	local options = {}

	for _, action in ipairs(world.sendEntityMessage(player.id(), "sbqActionList", "assign"):result() or {}) do
		local icon, shortdescription, description = sbq.getActionData(action.action, true, storage.iconDirectories)
		table.insert(options, {
			args = { "controllerAssign", action.action },
			clickArgs = true,
			name = shortdescription,
			icon = icon,
			locked = not action.available,
			description = description
		})
	end
	self:openRadialMenu({
		options = options,
		cancel = {
			args = { "open", "TopMenu" }
		}
	})
end

local OccupantsMenu = {}
RadialMenu.OccupantsMenu = OccupantsMenu
setmetatable(OccupantsMenu, _RadialMenu)
function OccupantsMenu:init()
	local options = {}
	local occupants = world.loungingEntities(player.id())

	for _, entityId in ipairs(occupants) do
		table.insert(options, {
			args = { "open", "SelectedOccupantMenu", entityId },
			name = world.entityName(entityId),
			icon = world.entityPortrait(entityId, "bust")
		})
	end
	self:openRadialMenu({
		options = options,
		cancel = {
			args = { "open", "TopMenu" },
		}
	})
end

local SelectedOccupantMenu = {}
RadialMenu.SelectedOccupantMenu = SelectedOccupantMenu
setmetatable(SelectedOccupantMenu, _RadialMenu)
function SelectedOccupantMenu:init(entityId)
	local options = {}

	for _, action in ipairs(world.sendEntityMessage(player.id(), "sbqActionList", "predRadialMenuSelect", entityId):result()
		or {}) do
		table.insert(options, {
			name = sbq.getString(action.name or (":" .. action.action)),
			args = { action.action, entityId, table.unpack(action.args or {}) },
			locked = not action.available,
			description = sbq.getString(action.description or (":" .. action.action .. "Desc")),
			message = "sbqTryAction"
		})
	end
	if world.isMonster(entityId) or world.isNpc(entityId) then
		table.insert(options, ((#options >= 1) and 2) or 1, {
			name = sbq.strings.interact,
			args = { entityId },
			message = "sbqInteractWithEntity",
			description = sbq.strings.interactDesc
		})
	end

	self:openRadialMenu({
		options = options,
		cancel = {
			args = { "open", "OccupantsMenu" }
		}
	})
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
			description = sbq.getString(action.description or (":" .. action.action .. "Desc")),
			message = "sbqTryAction"
		})
	end
	self:openRadialMenu({
		options = options,
		cancel = {
			args = { "open", "TopMenu" }
		}
	})
end
