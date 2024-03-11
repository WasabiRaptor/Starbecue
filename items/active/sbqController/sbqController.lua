
sbq = {}

require("/scripts/any/SBQ_RPC_handling.lua")
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
	if storage.action == "grab" then -- one unique case
		player.setScriptContext("starbecue")
		return player.callScript("sbq.tryAction", "grabRelease")
	end
end

function sbq.setAction(action)
	storage.action = action
	player.setScriptContext("starbecue")
	local icon, shortdescription, description = sbq.getActionData(action, (player.callScript("sbq.actionAvailable", action) or {})[1], storage.iconDirectory)
	activeItem.setInventoryIcon(icon)
	activeItem.setFriendlyName(shortdescription)
	activeItem.setDescription(description.."\n"..sbq.strings.controllerActionDescAppend)
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
    for _, action in ipairs(player.callScript("sbq.actionList") or config.getParameter("actions")) do
		if (player.callScript("sbq.actionAvailable", action) or {})[1] then
			local icon, shortdescription, description = sbq.getActionData(action, true, storage.iconDirectory)
			table.insert(options, {
				args = {"controllerAssign", action},
				name = shortdescription,
                icon = icon,
				description = description
			})
		end
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
			script = "sbq.tryAction"
        }
    }
	if world.isMonster(occupant.entityId) or world.isNpc(occupant.entityId) then
        table.insert(options, {
            name = sbq.strings.interact,
			args = {occupant.entityId},
			script = "player.interactWithEntity"
		})
	end
	player.setScriptContext("starbecue")
    local occupant, location = table.unpack(player.callScript("sbq.getOccupantData", entityId) or {})
	if (not occupant) or (not location) then animator.playSound("error") RadialMenu:open("OccupantsMenu") return end
	for _, action in ipairs(location.locationActions or {}) do
        local available, reason = table.unpack(player.callScript("sbq.actionAvailable", action.action, entityId))
		if (reason ~= "targetSettingsMismatch") and (reason ~= "settingsMismatch") and (reason ~= "invalidAction") then
			table.insert(options, {
				name = sbq.getString(action.name or (":"..action.action)),
				args = { action.action, entityId, table.unpack(action.args or {}) },
				locked = not available,
				icon = action.icon,
				description = sbq.getString(action.description or (":"..action.action.."Desc")),
				script = "sbq.tryAction"
			})
		end
    end

    self:openRadialMenu({ options = options, cancel = {
		args = {"open","OccupantsMenu"}
	}})
end
