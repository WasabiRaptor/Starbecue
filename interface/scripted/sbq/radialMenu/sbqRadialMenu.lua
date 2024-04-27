local options
local default
local cancel

local canvas
local button
local pressed
local activeSegment

function init()
	options = config.getParameter("options")
	default = config.getParameter("default") or {}
	cancel = config.getParameter("cancel") or {}
	if not options then
		pane.dismiss() -- empty radial menu, uh oh
	end
	local minOptions = config.getParameter("minOptions") or 2
	if #options < minOptions then
		for i = #options, minOptions-1 do
			table.insert(options,{locked = true})
		end
	end
	for _, option in ipairs(options) do
		setmetatable(option, {__index = default})
	end
	setmetatable(cancel, {__index = default})


	canvas = widget.bindCanvas( "canvas" )
	widget.focus("canvas")
end

function uninit()
	if config.getParameter("selectOnClose") then
		selectAction()
	end
end

function radialPoint(theta, radius)
	return {
		100 + radius * math.sin(theta * math.pi/180),
		100 + radius * math.cos(theta * math.pi/180)
	}
end

function generateSegment(size, angle, sides, spacingOffset, inner, outer)
	-- generate points
	local innerpoints = {}
	local outerpoints = {}
	local sideSize = size / sides
	for j = 1, (sides + 1) do
		local sideAngle = angle + sideSize * (j - 1)
		-- add points at *
		--	 *---*---* outer
		--	 |\ / \ /|
		-- * o-*---*-o inner
		table.insert(innerpoints, radialPoint(sideAngle - sideSize/2, inner))
		table.insert(outerpoints, radialPoint(sideAngle, outer))
	end
	-- fix end points at o
	innerpoints[1] = radialPoint(angle + spacingOffset, inner)
	table.insert(innerpoints, radialPoint(angle + size - spacingOffset, inner))

	-- generate tris
	-- 1---2---3 outer
	-- |\ / \ /|
	-- 1-2---3-3 inner
	local tris = {}
	table.insert(tris, {innerpoints[1], outerpoints[1], innerpoints[2]})
	for j = 2, (sides + 1) do
		table.insert(tris, {outerpoints[j - 1], innerpoints[j], outerpoints[j]})
		table.insert(tris, {innerpoints[j], outerpoints[j], innerpoints[j + 1]})
	end
	return tris
end

function update( dt )

	if options == nil then return end

	local segments = #options
	local segmentSpacing = 3
	local spacingOffset = 1 -- difference from segmentSpacing
	local sidesPerSegment
	local innerRadius
	if segments <= 6 then
		sidesPerSegment = 10
		innerRadius = 30
	elseif segments <= 10 then
		sidesPerSegment = 5
		innerRadius = 40
	else
		sidesPerSegment = 2
		innerRadius = 70
		spacingOffset = 0.5
	end
	local segmentSize = 360 / segments
	local iconRadius = innerRadius + 10
	local outerRadius = innerRadius + 20

	-- mouse handling
	local mpos = canvas:mousePosition()
	if mpos[1] == 0 and mpos[2] == 0 then mpos = {100, 100} end -- mouse position assumes {0, 0} until it is moved
	mpos = {mpos[1] - 100, mpos[2] - 100} -- move (0, 0) to center instead of corner
	local mouseAngle = math.atan(mpos[1], mpos[2]) * 180/math.pi + 180

	activeSegment = (math.floor(mouseAngle / segmentSize + 0.5) + segments) % segments + 1

	if math.sqrt(mpos[1]*mpos[1] + mpos[2]*mpos[2]) < 0.9*innerRadius then
		activeSegment = -1 -- no selection in middle
	end

	-- drawing
	canvas:clear()
	local tris = {}
	local activeTris = {}
	for i = 1, segments do
		local segmentAngle = segmentSize * (i - 1.5) + segmentSpacing / 2 + 180
		local r1, r2, ri, color
		if options[i].locked then
			r1 = innerRadius
			r2 = outerRadius - 15
			ri = iconRadius
			color = {170, 180, 190, 100}
		elseif i == activeSegment then
			r1 = innerRadius + 5
			r2 = outerRadius + 10
			ri = iconRadius + 7.5
			color = {200, 220, 240, 200}
		else
			r1 = innerRadius
			r2 = outerRadius
			ri = iconRadius
			color = {190, 200, 210, 100}
		end
		canvas:drawTriangles(
			generateSegment(segmentSize - segmentSpacing, segmentAngle, sidesPerSegment, spacingOffset, r1, r2),
			color
		)
		local textOffset = 0
		local iconPos = radialPoint(segmentSize * (i - 1) + 180, ri);
		if options[i].icon then
			if type(options[i].icon) == "table" then
				canvas:drawDrawables(options[i].icon, iconPos)
			else
				canvas:drawImage(options[i].icon, iconPos, nil, nil, true)
				local size = root.imageSize(options[i].icon)
				textOffset = (size[2] / 2) +3
			end
		end
		if iconPos[2] < 100 then
			textOffset = textOffset * -1
		end
		if options[i].name then
			drawShadowText(options[i].name, {iconPos[1], iconPos[2] + textOffset}, options[i].nameColor or options[i].textColor or {255,255,255}, 50, options[i].locked)
		end
	end

	local segment = options[activeSegment] or cancel or {}
	if segment.description then
		local color = {170, 180, 190, 200}
		local radius = innerRadius - (spacingOffset * 3)
		local triangles = {}
		local theta = 360 / (segments * sidesPerSegment)
		local first = radialPoint(0, radius)
		local prev = radialPoint(theta, radius)
		for i = 2, (segments * sidesPerSegment) - 1 do
			local point = radialPoint(theta * i, radius)
			table.insert(triangles, {first,point,prev})
			prev = point
		end
		canvas:drawTriangles(triangles, color)
		drawShadowText(segment.description, {100,100}, segment.descColor or segment.textColor or {255,255,255}, radius*2 )
	end
end

function drawShadowText(text, position, color, wrapWidth, greyed)
	local textBrightness = (greyed and 0.75 or 1)
	local shadowText = string.gsub(text, "%b^;", "")
	canvas:drawText(shadowText, {
		position = {position[1] + 0.5, position[2] - 0.5},
		horizontalAnchor = "mid",
		verticalAnchor = "mid",
		wrapWidth = wrapWidth
	}, 8, { 0, 0, 0 })
	canvas:drawText(shadowText, {
		position = {position[1], position[2] - 1},
		horizontalAnchor = "mid",
		verticalAnchor = "mid",
		wrapWidth = wrapWidth
	}, 8, { 0, 0, 0 })
	canvas:drawText(shadowText, {
		position = {position[1] + 1, position[2] - 1},
		horizontalAnchor = "mid",
		verticalAnchor = "mid",
		wrapWidth = wrapWidth
	}, 8, { 0, 0, 0 })
	canvas:drawText(text, {
		position = {position[1], position[2]},
		horizontalAnchor = "mid",
		verticalAnchor = "mid",
		wrapWidth = wrapWidth
	}, 8, { color[1] * textBrightness, color[2] * textBrightness, color[3] * textBrightness })
end

function canvasClickEvent(position, mouseButton, isButtonDown, shift, ctrl, alt)
	button = mouseButton
	pressed = isButtonDown

	if isButtonDown then
		selectAction(mouseButton, activeSegment, shift, ctrl, alt)
	end
end

function selectAction(...)
	local args = {}
	local option = options[activeSegment] or cancel

	if option.locked then return end
	local messageTarget = option.messageTarget or (pane.sourceEntity() == 0 and player.id()) or pane.sourceEntity()
	if option.clickArgs then
		args = {...}
	end
	if option.data then
		table.insert(args, 1, option.data)
	end
	for i, v in ipairs(option.args or {}) do
		table.insert(args, i,  v)
	end
	if option.context and option.script then
		player.setScriptContext(option.context)
		player.callScript(option.script, table.unpack(args))
	elseif option.message and world.entityExists(messageTarget) then
		world.sendEntityMessage(messageTarget, option.message, table.unpack(args))
	end
	if option.close then pane.dismiss() end
end
