sbq = {}

require("/scripts/any/SBQ_util.lua")
local buttons = {}
local indicator
local occupantData = {}
local colors = {
	-- color = {dark, light}
	default = {"404040", "6a6a6a"},
	white = {"8e8e8e", "ffffff"},
	black = {"404040", "000000"}, -- 'light' is actually darker here, for contrast
	red = {"6d0000", "b60000"},
	orange = {"764100", "d17300"},
	yellow = {"7c7100", "ddc900"},
	lime = {"467700", "76c800"},
	green = {"006200", "00b000"},
	cyan = {"007676", "00bebe"},
	teal = {"005290", "0072cb"},
	blue = {"262693", "3333ff"},
	purple = {"412693", "5c2de8"},
	violet = {"66009c", "8e00d9"},
	magenta = {"880088", "c500c5"},
}

local directions = { -- coordinates within indicator.png, measured from the *bottom*
	up = {42, 17, 49, 28},
	down = {42, 3, 49, 14},
	left = {33, 12, 44, 19},
	right = {47, 12, 58, 19},
	interact = {52, 22, 59, 29},
	special1 = {52, 2, 59, 9},
	special2 = {32, 2, 39, 9},
	special3 = {32, 22, 39, 29},
-- these ones could potentially be used, but aren't in the current layout
	-- space = {1, 1, 25, 7},
	-- primaryFire = {1, 35, 12, 41},
	-- secondaryFire = {14, 35, 25, 41},
	-- shift (only works if you're holding the controller)
}

local bar = {
	empty = "/interface/scripted/sbq/barempty.png",
	full = "/interface/scripted/sbq/barfull.png",
	x = 0, y = 34, h = 5, w = 61,
	color = {"9e9e9e", "c4c4c4", "e4e4e4", "ffffff"}, -- defaults in barfull.png
}

local predEnergyBar = {
	empty = "/interface/scripted/sbq/preyHud/energybar_empty.png",
	full = "/interface/scripted/sbq/preyHud/energybar.png",
	x = 30.5, y = 6, h = 4, w = 31,
}

function replace(from, to)
	if not to then return "" end
	local directive = "?replace;"
	for i, f in ipairs(from) do
		if to[i] then
			directive = directive .. f .. "=" .. to[i]:sub(1,6) .. ";"
		end
	end
	return directive
end

function init()
	sbq.strings = root.assetJson("/sbqStrings.config")
	processLocationData(config.getParameter("locationData"), config.getParameter("occupantData"))
	indicator = widget.bindCanvas("indicator")

	message.setHandler("sbqRefreshLocationData", function(_, _, id, locationData, newOccupantData)
		if id ~= pane.sourceEntity() then pane.dismiss() end
		world.sendEntityMessage(player.id(), "sbqSetCurrentLocationData", id, locationData, newOccupantData)
		player.setProperty("sbqPredPortrait", world.entityPortrait(id, "full"))
		player.setProperty("sbqPredWarpAttempted", 0)
		processLocationData(locationData, newOccupantData)
	end)

	update(0)
end

function processLocationData(locationData, newOccupantData)
	occupantData = newOccupantData
	local struggleActions = locationData.struggleActions or {}
	local canStruggle = not (occupantData.flags.digested or occupantData.flags.infused or occupantData.flags.digesting)
	buttons = {
		up = (struggleActions.up and canStruggle and (struggleActions.up.indicate or struggleActions.any.indicate or "default")),
		down = (struggleActions.down and canStruggle and (struggleActions.down.indicate or struggleActions.any.indicate or "default")),
		left = (struggleActions.left and canStruggle and (struggleActions.left.indicate or struggleActions.any.indicate or "default")),
		right = (struggleActions.right and canStruggle and (struggleActions.right.indicate or struggleActions.any.indicate or "default")),
		front = (struggleActions.front and canStruggle and (struggleActions.front.indicate or struggleActions.any.indicate or "default")),
		back = (struggleActions.back and canStruggle and (struggleActions.back.indicate or struggleActions.any.indicate or "default"))
	}
end
function indicateButton(dir, color)
	if not color then return end
	indicator:drawImageRect(
		"/interface/scripted/sbq/preyHud/indicator.png"
			.. replace(colors.default, colors[color]),
		directions[dir], directions[dir]
	)
end
local gracePeriod = 1
function update( dt )
	gracePeriod = math.max(0, gracePeriod - dt)
	if gracePeriod == 0 and (player.loungingIn() ~= pane.sourceEntity()) then
		pane.dismiss()
		return
	end

	-- drawing
	indicator:clear()

	-- buttons
	local lockDown = world.entity(pane.sourceEntity()):statPositive("sbqLockDown") and "black"
	indicateButton("interact", world.isEntityInteractive(pane.sourceEntity()) and "default" )
	indicateButton("up", (buttons.up and lockDown) or buttons.up )
	indicateButton("down", (buttons.down and lockDown) or buttons.down )

	local facingRight = world.entity(pane.sourceEntity()):facingDirection() == 1
	local left = (buttons.left or (facingRight and buttons.back) or buttons.front)
	indicateButton("left", (left and lockDown) or left)
	local right = (buttons.right or (facingRight and buttons.front) or buttons.back)
	indicateButton("right", (right and lockDown) or right )

	-- bar
	local s = (status.statusProperty("sbqProgressBar") or 0) * bar.w
	if s < bar.w then
		indicator:drawImageRect(
			bar.empty,
			{s, 0, bar.w, bar.h},
			{bar.x + s, bar.y, bar.x + bar.w, bar.y + bar.h}
		)
	end
	if s > 0 then
		indicator:drawImageRect(
			bar.full .. replace(bar.color, status.statusProperty("sbqProgressBarColor")),
			{0, 0, s, bar.h},
			{bar.x, bar.y, bar.x + s, bar.y + bar.h}
		)
	end

	-- time
	local hours = 1 -- if >1h, show hh:mm instead of mm:ss (not enough space for hh:mm:ss)
	if occupantData.time / 60 > 60 then hours = 60 end
	local first = tostring(math.floor(occupantData.time/60/hours/10))
	local second = tostring(math.floor(occupantData.time / 60 / hours % 10))
	indicator:drawText(
		first,
		{position = {10, 9}, horizontalAnchor = "right"},
		8, {127, 127, 127}
	)
	indicator:drawText(
		second,
		{position = {15, 9}, horizontalAnchor = "right"},
		8, {127, 127, 127}
	)
	if occupantData.time%2 < 1 then -- flash : for seconds
		indicator:drawText(
			":",
			{position = {17, 9}, horizontalAnchor = "right"},
			8, {127, 127, 127}
		)
	end
	indicator:drawText(
		tostring(math.floor(occupantData.time/hours/10%6)),
		{position = {22, 9}, horizontalAnchor = "right"},
		8, {127, 127, 127}
	)
	indicator:drawText(
		tostring(math.floor(occupantData.time/hours%10)),
		{position = {27, 9}, horizontalAnchor = "right"},
		8, {127, 127, 127}
	)
	occupantData.time = occupantData.time + dt

	-- location icon
	if occupantData.icon then
		indicator:drawImageDrawable(occupantData.icon, {15.5,15}, 1)
	end

	-- location
	local locationString = sbq.getString(occupantData.locationName or "")
	indicator:drawText(
		locationString,
		{position = {16.5, 29}, horizontalAnchor = "mid", wrapWidth = 25},
		6, {0, 0, 0}
	)
	indicator:drawText(
		locationString,
		{position = {15.5, 29}, horizontalAnchor = "mid", wrapWidth = 25},
		6, {0, 0, 0}
	)
	indicator:drawText(
		locationString,
		{position = {16, 29.5}, horizontalAnchor = "mid", wrapWidth = 25},
		6, {0, 0, 0}
	)
	indicator:drawText(
		locationString,
		{position = {16, 28.5}, horizontalAnchor = "mid", wrapWidth = 25},
		6, {0, 0, 0}
	)

	indicator:drawText(
		locationString,
		{position = {16, 29}, horizontalAnchor = "mid", wrapWidth = 25},
		6, {127, 127, 127}
	)

	if occupantData.indicatorIcon then
		indicator:drawImageDrawable(occupantData.indicatorIcon, {45.5,16}, 1)
	end
	if world.entity(pane.sourceEntity()):statPositive("sbqLockDown") then
		indicator:drawImageDrawable("/interface/scripted/sbq/lockedDisabled.png", { 45.5, 16 }, 1)

		local s = world.entity(pane.sourceEntity()):resourcePercentage("energy") * predEnergyBar.w
		if s < predEnergyBar.w then
			indicator:drawImageRect(
				predEnergyBar.empty,
				{s, 0, predEnergyBar.w, predEnergyBar.h},
				{predEnergyBar.x + s, predEnergyBar.y, predEnergyBar.x + predEnergyBar.w, predEnergyBar.y + predEnergyBar.h}
			)
		end
		if s > 0 then
			indicator:drawImageRect(
				predEnergyBar.full,
				{0, 0, s, predEnergyBar.h},
				{predEnergyBar.x, predEnergyBar.y, predEnergyBar.x + s, predEnergyBar.y + predEnergyBar.h}
			)
		end
	end
end

function uninit()
	if pane.sourceEntity() and world.entityExists(pane.sourceEntity()) then
		world.sendEntityMessage(pane.sourceEntity(), "indicatorClosed", player.id())
	end
end
