
sbq = {}

require("/scripts/any/SBQ_RPC_handling.lua")
require("/interface/scripted/sbq/sbqIndicatorHud/hudActions.lua")
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
		if RadialMenu[script] then
			RadialMenu[script](RadialMenu, ...)
        else
			sb.logInfo(string.format("[%s] Attmpted invalid radial menu script: %s(%s)", entity.id(), script, sb.printJson({...})))
    	end
	end)
	message.setHandler("sbqControllerCancel", function(_, _)
		RadialMenu:cancel()
	end)
end

local selectedPrey
local selectedPreyIndex

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
	if storage.action == "grab" then -- one unique case
		player.setScriptContext("starbecue")
		return player.callScript("sbq.tryAction", "grabRelease")
	end
end

function sbq.setAction(action)
	storage.action = action
	player.setScriptContext("starbecue")
	local icon, shortdescription, description = sbq.getActionData(action, player.callScript("sbq.actionAvailable", action), activeItem.directory(), storage.iconDirectory)
	activeItem.setInventoryIcon(icon)
	activeItem.setFriendlyName(shortdescription)
	activeItem.setDescription(description)
end

function sbq.letout(id)
	player.setScriptContext("starbecue")
	local loungeAnchor = world.entityCurrentLounge(entity.id())
	if (not loungeAnchor) or loungeAnchor.dismountable then
		return player.callScript("sbq.tryAction", "pickLetout", id, storage.action)
	end
end

function sbq.clickAction()
	if not storage.action then return false end
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
	player.setScriptContext("starbecue")
	local result
	for i, targetId in ipairs(entityaimed) do
		for j, eid in ipairs(entityInRange) do
			if targetId == eid and entity.entityInSight(targetId) then
				local loungeAnchor = world.entityCurrentLounge(targetId)
				if (not loungeAnchor) or loungeAnchor.dismountable then
					result = player.callScript("sbq.tryAction", storage.action, targetId)
					break
				end
			end
		if result and result[1] then break end
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
function RadialMenu:open(menuName)
	if self.activeMenu then
		self.activeMenu:uninit()
	end
	if self[menuName] and self[menuName].isMenu then
		self.activeMenuName = menuName
		self.activeMenu = self[menuName]
        self.activeMenu:init()
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
	player.interact("ScriptPane", {baseConfig = "/interface/scripted/sbq/sbqClose/sbqClose.config"}, player.id())
end

_RadialMenu = {isMenu = true}
_RadialMenu.__index = _RadialMenu
function _RadialMenu:init()
end
function _RadialMenu:update()
end
function _RadialMenu:uninit()
end
function _RadialMenu:cancel()
end
function _RadialMenu:openRadialMenu(overrides)
    player.interact("ScriptPane", sb.jsonMerge(
		{
			baseConfig = "/interface/scripted/sbq/sbqRadialMenu/sbqRadialMenu.config",
			selectOnClose = true,
			default = {
				context = "starbecue",
				message = "sbqControllerRadialMenuScript"
			},
			cancel = {
				message = "sbqControllerCancel",
				script = false,
			},
		},
		overrides
	), player.id())
end

function _RadialMenu:controllerAssign(action)
	sbq.setAction(action)
end

function _RadialMenu:letout()
	sbq.letout()
end
function _RadialMenu:letoutTarget(id)
	sbq.letout(id)
end

local TopMenu = {}
RadialMenu.TopMenu = TopMenu
setmetatable(TopMenu, _RadialMenu)
function TopMenu:init()
	local options = {
		{
			args = {"letout"},
			name = sbq.strings.controllerLetOut,
		},
		{
			args = {"open","AssignMenu"},
			name = sbq.strings.controllerAssign
		}
	}
	self:openRadialMenu({options = options})
end

local AssignMenu = {}
RadialMenu.AssignMenu = AssignMenu
setmetatable(AssignMenu, _RadialMenu)
function AssignMenu:init()
	local options = {
		{
			args = {"open","TopMenu"},
			name = "<-",
		}
	}
	for _, action in ipairs(player.callScript("sbq.actionList") or config.getParameter("actions")) do
		if player.callScript("sbq.actionAvailable", action) then
			local icon, shortdescription, description = sbq.getActionData(action, true, activeItem.directory(), storage.iconDirectory)
			table.insert(options, {
				args = {"controllerAssign", action},
				name = shortdescription,
				icon = icon
			})
		end
	end
	self:openRadialMenu({options = options})
end
