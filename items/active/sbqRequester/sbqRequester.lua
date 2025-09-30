sbq = {}
require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/rect.lua"
require "/scripts/poly.lua"
require "/scripts/interp.lua"
require "/scripts/any/SBQ_RPC_handling.lua"
require "/items/active/sbqRequester/sbqRequesterSetup.lua"
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

	message.setHandler("sbqRequesterRadialMenuScript", function(_, _, script, ...)
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
	world.sendEntityMessage(player.id(), "sbqQueueAction", "rpActionReset")
end

function sbq.setAction(fireMode, action)
	storage.actions[fireMode] = action

	local icon, shortdescription, description = sbq.getRequestActionData(storage.actions.primary, storage.iconDirectories)
	local icon2, shortdescription2, description2 = sbq.getRequestActionData(storage.actions.alt, storage.iconDirectories)

	activeItem.setInventoryIcon(icon or "/humanoid/any/sbqActionIcons/unassigned.png")
	activeItem.setSecondaryIcon(icon2 or "/humanoid/any/sbqActionIcons/unassigned.png")
	activeItem.setShortDescription(sbq.getString(":requesterShortDescFormat"):format(shortdescription))
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
		includedTypes = { "creature", "object" }
	})

	world.sendEntityMessage(player.id(), "sbqQueueAction", "rpActionReset")
	local bounds = mcontroller.collisionBoundBox()
	local paddedbounds = rect.pad(bounds, sbq.config.actionRange * mcontroller.getScale())
	local success, failReason
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
			success, failReason = sbq.attemptRequest(action, targetId)
			if success then break end
		end
	end

	if (not success) and (failReason ~= "targetMissing") then
		animator.playSound("error")
		interface.queueMessage(sbq.getString(":request_" .. tostring(failReason)))
	end
	return success, failReason
end

function sbq.attemptRequest(action, target)
	local consent = shiftHeldTime > 0
	local targetAction = (sbq.getPublicProperty(target, "sbqActionData") or {})[action]
	if not targetAction then return false, "missingAction" end
	if world.entity(target):statPositive("sbqIsPrey") or world.entity(target):statPositive("sbqEntrapped") then return false, "isPrey" end
	local targetSettings = sbq.getPublicProperty(target, "sbqPublicSettings") or {}
	local targetBehaviorSettings = (targetSettings.domBehavior or {})[action] or {}
	if (not consent) and targetBehaviorSettings.consentRequired then return false, "consentRequired" end
	if not world.sendEntityMessage(player.id(), "sbqSettingsMatches", targetAction.targetSettings, true):result() then return false, "targetSettingsMismatch" end

	if consent then
		sbq.addRPC(world.sendEntityMessage(target, "sbqPromptAction", entity.id(), action, false), function(response)
			if response then sbq.addRPC(world.sendEntityMessage(player.id(), "sbqPromptResponse", table.unpack(response)), sbq.requestResults) end
		end)
	else
		sbq.addRPC(world.sendEntityMessage(target, "sbqRequestAction", true, action, entity.id()), sbq.requestResults)
	end
	return true
end
function sbq.requestResults(result)
	local success, failReason, time, successfulFail, failReason2 = table.unpack(result or { false, "messageNotHandled" })
	if (not success) and (failReason ~= "targetMissing") then
		animator.playSound("error")
		interface.queueMessage(sbq.getString(":request_" .. tostring(failReason)))
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
				message = "sbqRequesterRadialMenuScript"
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
	local options = {
		{locked = true},
		{
			args = { "open", "RoleplayMenu" },
			name = sbq.getString(":controllerRPMenu"),
			description = sbq.getString(":controllerRPMenuDesc")
		},
		{locked = true},
		{
			args = { "open", "AssignMenu" },
			name = sbq.getString(":controllerAssign"),
			description = sbq.getString(":controllerAssignDesc")
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

	for _, action in ipairs(sbq.gui.voreTypeOrder) do
		if world.sendEntityMessage(player.id(), "sbqGetSetting", "prey", "vorePrefs", action):result() then
			local icon, shortdescription, description = sbq.getRequestActionData(action, storage.iconDirectories)
			table.insert(options, {
				args = { "controllerAssign", action },
				clickArgs = true,
				name = shortdescription,
				icon = icon,
				description = description
			})
		end
	end
	for _, action in ipairs(sbq.gui.infuseTypeOrder) do
		if world.sendEntityMessage(player.id(), "sbqGetSetting", "prey", "infusePrefs", action):result() then
			local icon, shortdescription, description = sbq.getRequestActionData(action, storage.iconDirectories)
			table.insert(options, {
				args = { "controllerAssign", action },
				clickArgs = true,
				name = shortdescription,
				icon = icon,
				description = description
			})
		end
	end

	self:openRadialMenu({
		options = options,
		cancel = {
			args = { "open", "TopMenu" }
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
