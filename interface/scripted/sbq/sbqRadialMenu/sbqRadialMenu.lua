local options
local menuType
local canvas
local button
local pressed

function init()
	options = config.getParameter( "options" )
	menuType = config.getParameter("type")
	if not options then
		pane.dismiss() -- empty radial menu, uh oh
	end

	canvas = widget.bindCanvas( "canvas" )
	widget.focus("canvas")
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
		innerRadius = 20
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
	local activeSegment = (math.floor(mouseAngle / segmentSize + 0.5) + segments) % segments + 1
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
		if i == activeSegment then
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
		local iconPos = radialPoint(segmentSize * (i - 1) + 180, ri);
		if options[i].icon then
			canvas:drawImage(options[i].icon, iconPos, nil, nil, true)
		else
			canvas:drawText(options[i].title or options[i].name, {
				position = {iconPos[1] + 0.5, iconPos[2] - 0.5},
				horizontalAnchor = "mid",
				verticalAnchor = "mid"
			}, 8, { 0, 0, 0 })
			canvas:drawText(options[i].title or options[i].name, {
				position = {iconPos[1] + 1, iconPos[2] - 1},
				horizontalAnchor = "mid",
				verticalAnchor = "mid"
			}, 8, {0, 0, 0})
			canvas:drawText(options[i].title or options[i].name, {
				position = iconPos,
				horizontalAnchor = "mid",
				verticalAnchor = "mid"
			}, 8)
		end
	end

	-- save selection
	if activeSegment == -1 then
		player.setProperty( "sbqRadialSelection", {selection = "cancel", type = menuType, button = button, pressed = pressed})
	else
		player.setProperty( "sbqRadialSelection", {selection = options[activeSegment].name, data = options[activeSegment].data, type = menuType, button = button, pressed = pressed} )
	end
end

function canvasClickEvent(position, mouseButton, isButtonDown, shift, ctrl, alt)
	button = mouseButton
	pressed = isButtonDown
end
