
function _ENV.metagui.theme.drawFrame() -- maybe this could stop the background from drawing
end

function init()
	local backingCanvas = widget.bindCanvas(_ENV.frame.backingWidget .. ".canvas")
	backingCanvas:clear()
	player.setScriptContext("starbecue")
	player.callScript("sbq.predHudOpen", true)

	message.setHandler("sbqDismissPredHud", function(_, _)
		pane.dismiss()
	end)
	message.setHandler("sbqRefreshHudOccupants", function(_, _, occupants, settingsData)
		Occupants.list = occupants
		for k, v in pairs(settingsData) do
			sbq[k] = v
		end
		if sbq.storageSettings then
			storage.sbqSettings = sbq.storageSettings or {}
			storage.sbqUpgrades = sbq.storageUpgrades or {}
			sbq.setupSettingMetatables(world.entityType(sbq.entityId()))
		end
		if sbq.locations and sbq.baseLocations then
			for name, location in pairs(sbq.locations) do
				setmetatable(location, {__index = sbq.baseLocations[name]})
			end
		end
		sbq.assignSettingValues()
		sbq.refreshSettingVisibility()
		sbq.refreshOccupants()
	end)
	message.setHandler("sbqPredHudPreyDialogue", function(_, _, entityId, dialogue, sound, speed, volume, lifetime)
		if not world.entityExists(entityId) then return end
		local portrait = _ENV[entityId .. "PortraitCanvas"]
		if portrait then
			local pos = { 0, 0 }
			local w = portrait
			while w.parent do
				pos = vec2.add(pos, w.position)
				w = w.parent
			end
			if (pos[2] < 205) and (pos[2] > 19) then
				_ENV.metagui.preyDialogueText({6, 256 - pos[2] + (portrait.size[2]/2)}, dialogue, sound, speed, volume, entityId.."HudDialogue", lifetime)
			end
			sbq.refreshPortrait(entityId)
		end
	end)
	message.setHandler("sbqHudRefreshPortrait",function (_,_,entityId)
		sbq.refreshPortrait(entityId)
	end)

	Occupants.list = _ENV.metagui.inputData.occupants
	sbq.refreshOccupants()
	sbq.changeLocation(1)
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

function uninit()
	player.setScriptContext("starbecue")
	player.callScript("sbq.predHudOpen", false)
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
			local actions = {}
			player.setScriptContext("starbecue")
			for _, action in ipairs(player.callScript("sbq.actionList", "predHudSelect", occupant.entityId) or {}) do
				if action.available then
					table.insert(actions, {
						_ENV.metagui.formatText(action.name or (":"..action.action)),
						function()
							player.setScriptContext("starbecue")
							player.callScript("sbq.queueAction", action.action, occupant.entityId, table.unpack(action.args or {}))
						end,
						_ENV.metagui.formatText(action.description or (":"..action.action.."Desc"))
					})
				else
					table.insert(actions, {
						"^#555;^set;" .. _ENV.metagui.formatText(action.name or (":" .. action.action)),
						function() end,
						_ENV.metagui.formatText(action.description or (":"..action.action.."Desc"))
					})
				end
			end
			if world.isMonster(occupant.entityId) or world.isNpc(occupant.entityId) then
				table.insert(actions, ((#actions >= 1) and 2) or 1, { sbq.strings.interact, function()
					player.interactWithEntity(occupant.entityId)
				end, sbq.strings.interactDesc})
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
		if world.entityExists(occupant.entityId) then
			sbq.progressBar(_ENV[occupant.entityId .. "HealthBar"], HPPal, world.entityResourcePercentage(occupant.entityId, "health"))
			sbq.progressBar( _ENV[occupant.entityId.."ProgressBar"], sbq.getPublicProperty(occupant.entityId, "sbqProgressBarColor"), sbq.getPublicProperty(occupant.entityId, "sbqProgressBar") or 0 )
		end
	end
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

sbq.locationIndex = 0
function sbq.changeLocation(dir)
	local i, location, locationData = sbq.nextValidLocationIndex(dir)
	if not i then return end
	sbq.locationIndex = i
	_ENV.effectsPanel:clearChildren()
	_ENV.effectsPanel:addChild({ type = "scrollArea", scrollBars = false, scrollDirections = {1,0}, children = {
		{ mode = "v", spacing = -2 },
		{ type = "spacer", size = 1 },
		{type = "sbqSetting", setting = "mainEffect", groupName = "locations", groupKey = location},
		{type = "sbqSetting", setting = "secondaryEffects", groupName = "locations", groupKey = location}
	}, })
	sbq.assignSettingValues()
	sbq.refreshSettingVisibility()

	local j, nextLocation, nextLocationData = sbq.nextValidLocationIndex(1)
	local _, prevLocation, prevLocationData = sbq.nextValidLocationIndex(-1)
	if j == sbq.locationIndex then
		_ENV.prevLocation:setVisible(false)
		_ENV.nextLocation:setVisible(false)
		return
	end
	if prevLocationData then
		_ENV.prevLocation.toolTip = sbq.getString(prevLocationData.name or (":" .. prevLocation))
		_ENV.prevLocation:setVisible(true)
	else
		_ENV.prevLocation:setVisible(false)
	end
	if nextLocationData then
		_ENV.nextLocation.toolTip = sbq.getString(nextLocationData.name or (":" .. nextLocation))
		_ENV.nextLocation:setVisible(true)
	else
		_ENV.nextLocation:setVisible(false)
	end
end

function sbq.nextValidLocationIndex(dir)
	local wrapped = false
	local location
	local locationData
	local locationOrder = sbq.voreConfig.locationOrder or sbq.gui.locationOrder
	local i = sbq.locationIndex
	while true do
		i = i + dir
		if i > #locationOrder then
			if wrapped then return end
			wrapped = true
			i = 1
		elseif i < 1 then
			if wrapped then return end
			wrapped = true
			i = #locationOrder
		end
		location = locationOrder[i]
		locationData = sbq.locations[location]
		if locationData and sbq.tableMatches(locationData.activeSettings, sbq.settings, true) then
			return i, location, locationData
		end
	end
end

----------------------------------------------------------------------------------------------------------------

function _ENV.settings:onClick()
	player.interact("ScriptPane", { gui = { }, scripts = {"/metagui/sbq/build.lua"}, ui = "starbecue:playerSettings" })
end

function _ENV.prevLocation:onClick()
	sbq.changeLocation(-1)
end
function _ENV.nextLocation:onClick()
	sbq.changeLocation(1)
end
function _ENV.lockDown:onClick()
	player.setScriptContext("starbecue")
	if status.statPositive("sbqLockDown") then
		player.callScript("sbq.queueAction", "lockDownClear")
	else
		player.callScript("sbq.queueAction", "lockDown")
	end
end


----------------------------------------------------------------------------------------------------------------
