
function _ENV.metagui.theme.drawFrame() -- maybe this could stop the background from drawing
end

function init()
	local backingCanvas = widget.bindCanvas(_ENV.frame.backingWidget .. ".canvas")
    backingCanvas:clear()

	message.setHandler("sbqRefreshHudOccupants", function (_,_, occupants)
        Occupants.list = occupants
		sbq.refreshOccupants()
    end)
    Occupants.list = _ENV.metagui.inputData.occupants
	sbq.refreshOccupants()
end

Occupants = {
    list = {},
	entityId = {}
}

function update()
	local dt = script.updateDt()
	sbq.checkRPCsFinished(dt)
	sbq.checkTimers(dt)
	sbq.updateBars(dt)
end

local occupantTemplate = root.assetJson("/interface/scripted/sbq/predatorHud/occupantLayout.config")
function sbq.refreshOccupants()
	Occupants.entityId = {}
    _ENV.occupantSlots:clearChildren()
    local occupants = #Occupants.list
    _ENV.occupantSlots:addChild({ type = "spacer", size = 25 * (math.max(occupants, sbq.gui.predHudMaxOccupants) + 1) + 5 })
    for _, occupant in ipairs(Occupants.list) do
		local layout = sbq.replaceConfigTags(occupantTemplate, { entityId = occupant.entityId, entityName = world.entityName(occupant.entityId) })
		Occupants.entityId[tostring(occupant.entityId)] = occupant
        _ENV.occupantSlots:addChild(layout)
        sbq.refreshPortrait(occupant.entityId)
		local ActionButton = _ENV[occupant.entityId.."ActionButton"]
        function ActionButton:onClick()
            local actions = {
				{ sbq.strings.letout, function ()
					player.setScriptContext("starbecue")
					player.callScript("sbq.tryAction", "letout", occupant.entityId)
				end}
			}
			if world.isMonster(occupant.entityId) or world.isNpc(occupant.entityId) then
                table.insert(actions, { sbq.strings.interact, function()
					player.interactWithEntity(occupant.entityId)
				end})
            end
			player.setScriptContext("starbecue")
			local occupant, location = table.unpack(player.callScript("sbq.getOccupantData", occupant.entityId) or {})
			if (not occupant) or (not location) then animator.playSound("error") RadialMenu:open("OccupantsMenu") return end
			for _, action in ipairs(location.locationActions or {}) do
				local available, reason = table.unpack(player.callScript("sbq.actionAvailable", action.action, occupant.entityId))
                if (reason ~= "targetSettingsMismatch") and (reason ~= "settingsMismatch") and (reason ~= "invalidAction") then
					if available then
                        table.insert(actions, { sbq.getString(action.name or (":" .. action.action)), function()
							player.setScriptContext("starbecue")
							player.callScript("sbq.tryAction", action.action, occupant.entityId, table.unpack(action.args or {}))
                        end, })
                    else
						table.insert(actions, {"^#555;"..sbq.getString(action.name or (":"..action.action)), function () end})
					end
				end
            end
			_ENV.metagui.dropDownMenu(actions,2)
		end
    end
	_ENV.occupantSlots:addChild({ type = "spacer", size = 25 * (occupants + 1) })
    _ENV.predHudTop:setVisible((occupants >= 8))
	sbq.updateBars(0)
end

local HPPal = {"751900", "c61000", "f72929", "ffa5a5"}

sbq.topBar = {
	empty = "/interface/scripted/sbq/barempty.png",
	full = "/interface/scripted/sbq/barfull.png",
	x = 0, y = 0, h = 5, w = 61,
	color = {"9e9e9e", "c4c4c4", "e4e4e4", "ffffff"}, -- defaults in barfull.png
}

sbq.bottomBar = {
	empty = "/interface/scripted/sbq/barempty.png?flipy",
	full = "/interface/scripted/sbq/barfull.png?flipy",
	x = 0, y = 0, h = 5, w = 61,
	color = {"9e9e9e", "c4c4c4", "e4e4e4", "ffffff"}, -- defaults in barfull.png
}

function sbq.updateBars(dt)
    for _, occupant in ipairs(Occupants.list) do
        sbq.progressBar(_ENV[occupant.entityId .. "HealthBar"], HPPal, world.entityResourcePercentage(occupant.entityId, "health"))
        if occupant.progressBar then
			occupant.progressBar.progress = occupant.progressBar.progress + (dt * (occupant.progressBar.args.speed or 1))
			sbq.progressBar( _ENV[occupant.entityId.."ProgressBar"], occupant.progressBar.args.color, (occupant.progressBar.progress or 0) / 100 )
		end
	end
end

function sbq.replace(from, to)
	if to == nil or #to == 0 then return "" end
	local directive = "?replace;"
	for i, f in ipairs(from) do
		directive = directive .. f .. "=" .. to[i]:sub(1,6) .. ";"
	end
	return directive
end

function sbq.progressBar(canvas, color, percent)
    if not canvas then return end
	local bar = sbq[canvas.data.bar]
	local progressBar = widget.bindCanvas( canvas.backingWidget )
	progressBar:clear()

	local s = percent * bar.w
	if s < bar.w then
		progressBar:drawImageRect(
			bar.empty,
			{s, 0, bar.w, bar.h},
			{bar.x + s, bar.y, bar.x + bar.w, bar.y + bar.h}
		)
	end
	if s > 0 then
		progressBar:drawImageRect(
			bar.full .. sbq.replace(bar.color, color),
			{0, 0, s, bar.h},
			{bar.x, bar.y, bar.x + s, bar.y + bar.h}
		)
	end
end

function sbq.refreshPortrait(entityId)
    local canvasWidget = _ENV[entityId .. "PortraitCanvas"]
	if not canvasWidget then return end
	local canvas = widget.bindCanvas( canvasWidget.backingWidget )
    canvas:clear()
	canvas:drawDrawables(world.entityPortrait(entityId, "bust"), vec2.sub(vec2.div(canvasWidget.size, 2), {0,6}))
end

----------------------------------------------------------------------------------------------------------------

function _ENV.settings:onClick()
	player.interact("ScriptPane", { gui = { }, scripts = {"/metagui/sbq/build.lua"}, ui = "starbecue:playerSettings" })
end

----------------------------------------------------------------------------------------------------------------
