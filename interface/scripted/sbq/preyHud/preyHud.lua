sbq = {}

require("/scripts/any/SBQ_util.lua")
local buttons = {}
local indicator
local occupantFlags = {}
local time = 0
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

	message.setHandler("sbqRefreshLocationData", function(_, _, id, locationData, occupantData)
		if id ~= pane.sourceEntity() then pane.dismiss() end
		player.setScriptContext("starbecue")
		player.callScript("sbq.setCurrentLocationData", locationData, occupantData)
		processLocationData(locationData, occupantData)
	end)

	update(0)
end

function processLocationData(locationData, occupantData)
	local struggleActions = locationData.struggleActions or {}
	local canStruggle = not (occupantData.digested or occupantData.infused)
	occupantFlags = occupantData
	time = occupantData.time
	buttons = {
		up = (struggleActions.up and canStruggle and (struggleActions.up.indicate or struggleActions.any.indicate or "default")),
		down = (struggleActions.down and canStruggle and (struggleActions.down.indicate or struggleActions.any.indicate or "default")),
		left = (struggleActions.left and canStruggle and (struggleActions.left.indicate or struggleActions.any.indicate or "default")),
		right = (struggleActions.right and canStruggle and (struggleActions.right.indicate or struggleActions.any.indicate or "default")),
		front = (struggleActions.front and canStruggle and (struggleActions.front.indicate or struggleActions.any.indicate or "default")),
		back = (struggleActions.back and canStruggle and (struggleActions.back.indicate or struggleActions.any.indicate or "default"))
	}
	time = occupantData.time
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
	local lockDown = world.entityStatPositive(pane.sourceEntity(), "sbqLockDown") and "black"
	indicateButton("interact", world.isEntityInteractive(pane.sourceEntity()) and "default" )
	indicateButton("up", buttons.up and lockDown or buttons.up )
	indicateButton("down", buttons.down and lockDown or buttons.down )

	local facingRight = player.callScript("mcontroller.facingDirection") == 1
	local left = (buttons.left or (facingRight and buttons.back) or buttons.front)
	indicateButton("left", left and lockDown or left)
	local right = (buttons.right or (facingRight and buttons.front) or buttons.back)
	indicateButton("right", right and lockDown or right )

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
	if time / 60 > 60 then hours = 60 end
	local first = tostring(math.floor(time/60/hours/10))
	local second = tostring(math.floor(time / 60 / hours % 10))
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
	if time%2 < 1 then -- flash : for seconds
		indicator:drawText(
			":",
			{position = {17, 9}, horizontalAnchor = "right"},
			8, {127, 127, 127}
		)
	end
	indicator:drawText(
		tostring(math.floor(time/hours/10%6)),
		{position = {22, 9}, horizontalAnchor = "right"},
		8, {127, 127, 127}
	)
	indicator:drawText(
		tostring(math.floor(time/hours%10)),
		{position = {27, 9}, horizontalAnchor = "right"},
		8, {127, 127, 127}
	)
	time = time + dt

	-- location icon
	if root.assetExists("/interface/scripted/sbq/"..occupantFlags.location..".png") then
		indicator:drawImageDrawable("/interface/scripted/sbq/"..occupantFlags.location..".png", {15.5,15}, 1)
	end

	-- location
	local locationString = sbq.getString(occupantFlags.locationName or "")
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

	if occupantFlags.infused and occupantFlags.infuseType and root.assetExists("/interface/scripted/sbq/"..occupantFlags.infuseType..".png") then
		indicator:drawImageDrawable("/interface/scripted/sbq/"..occupantFlags.infuseType..".png", {45.5,16}, 1)
	elseif occupantFlags.digested then
		indicator:drawImageDrawable("/interface/scripted/sbq/softDigest.png", {45.5,16}, 1)
	elseif world.entityStatPositive(pane.sourceEntity(), "sbqLockDown") then
		indicator:drawImageDrawable("/interface/scripted/sbq/lockedDisabled.png", {45.5,16}, 1)
	end
end

function uninit()
	if pane.sourceEntity() and world.entityExists(pane.sourceEntity()) then
		world.sendEntityMessage(pane.sourceEntity(), "indicatorClosed", player.id())
	end
end
