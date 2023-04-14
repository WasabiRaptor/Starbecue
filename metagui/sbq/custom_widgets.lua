---@diagnostic disable: undefined-global
local mg = metagui ---@diagnostic disable-line: undefined-global
local widgets = mg.widgetTypes
local mkwidget = mg.mkwidget

-- first off, modify textBox to actually use given size
function widgets.textBox:preferredSize() return self.explicitSize or {96, 14} end

widgets.slider = mg.proto(mg.widgetBase, {
	expandMode = {1, 0}, -- will expand horizontally, but not vertically
	widgetType = "slider"
})

function widgets.slider:init(base, param)
	self.expandMode = param.expandMode
	self.textToolTips = param.textToolTips

	if param.inline then self.expandMode = {0, 0} end
	if param.expand then self.expandMode = {2, 0} end

	self.notches = param.notches or {param.min, param.max}
	if #self.notches < 2 or self.notches[1] >= self.notches[#self.notches] then
		sb.logError("Slider with invalid min/max! id: " .. self.id)
	end

	self.handles = param.handles or {{value = param.value or self.notches[1], toolTip = param.toolTip, locked = param.locked or param.disabled or false}}
	if #self.handles < 1 then
		sb.logError("Slider with no handles! id: " .. self.id)
	end
	for i, h in ipairs(self.handles) do
		if not h.value then
			sb.logError("Slider handle with no value! id: " .. self.id .. ", index: " .. i)
		end
		if not h.toolTip then
			h.toolTip = ""
		end
		if h.locked == nil then
			h.locked = false
		end
	end

	self.backingWidget = mkwidget(base, {type = "canvas"})
	self.image = "/metagui/sbq/slider_handles.png"
	self.mouseIsOver = false
	self.redraw = true
end

function widgets.slider:minSize() return {16, 16} end
function widgets.slider:preferredSize() return {64, 16} end

function widgets.slider:draw()
	-- update every frame while mouse is nearby

	local f = (self.size[1] - 16) / (self.notches[#self.notches] - self.notches[1])
	local s = self.notches[1] - 8 / f
	local m = self.size[2] / 2

	local last = self.current
	if not self:hasMouse() then -- don't change hover focus if currently dragging
		if self.mouseIsOver then
			local rmp = self:relativeMousePosition()
			local best = 1
			local dist = math.huge
			for i, h in ipairs(self.handles) do
				local d = rmp[1] - math.min(self.size[1], math.max(0, f * (h.value - s)))
				if math.abs(d) < dist and not h.locked or (math.abs(d) == dist and d > 0) then
					best = i
					dist = math.abs(d)
				end
			end
			last = self.current
			if dist < 6 then
				self.current = best
			else
				self.current = nil
			end
		else
			self.current = nil
		end
	end

	if self.mouseIsOver or self.current then
		self:queueRedraw() -- check mouse next frame too
	end

	if not self.redraw and not self:hasMouse() and self.current == last then
		return
	end
	self.redraw = false

	-- actually draw only if something changed

	local c = widget.bindCanvas(self.backingWidget)
	c:clear()

	local darkColor = { 0, 0, 0 }

	local lightColor = { 128, 128, 128 }

	if #self.handles > 1 then
		c:drawLine({8, m}, {self.size[1] - 8, m}, darkColor, 4)
		c:drawLine({math.floor(f * (self.handles[1].value - s)), m}, {math.floor(f * (self.handles[#self.handles].value - s)), m}, lightColor, 4)
	else
		c:drawLine({8, m}, {self.size[1] - 8, m}, lightColor, 4)
	end

	for i, n in ipairs(self.notches) do
		local color = lightColor
		if #self.handles > 1 and (n < self.handles[1].value or n > self.handles[#self.handles].value) then
			color = darkColor
		end
		if i == 1 then
			c:drawLine({math.floor(f * (n - s)), m - 5}, {math.floor(f * (n - s)), m + 5}, color, 4)
		elseif i == #self.notches then
			c:drawLine({math.floor(f * (n - s)) + 1, m - 5}, {math.floor(f * (n - s)) + 1, m + 5}, color, 4)
		else
			c:drawLine({math.floor(f * (n - s)) + 0.5, m - 3}, {math.floor(f * (n - s)) + 0.5, m + 3}, color, 2)
		end
	end

	if #self.handles > 1 then
		c:drawImage(self.image..":min"..(self.handles[1].locked and ".locked" or self.current == 1 and ".hover" or ""), {math.min(self.size[1], math.max(0, math.floor(f * (self.handles[1].value - s)))), m}, 1, {255, 255, 255}, true)
		c:drawImage(self.image..":max"..(self.handles[#self.handles].locked and ".locked" or self.current == #self.handles and ".hover" or ""), {math.min(self.size[1], math.max(0, math.floor(f * (self.handles[#self.handles].value - s)))), m}, 1, {255, 255, 255}, true)
		for i = 2, #self.handles - 1 do
			c:drawImage(self.image..":val"..(self.handles[i].locked and ".locked" or self.current == i and ".hover" or ""), {math.min(self.size[1], math.max(0, math.floor(f * (self.handles[i].value - s)))), m}, 1, {255, 255, 255}, true)
		end
	else
		c:drawImage(self.image..":val"..(self.handles[1].locked and ".locked" or self.current == 1 and ".hover" or ""), {math.min(self.size[1], math.max(0, math.floor(f * (self.handles[1].value - s)))), m}, 1, {255, 255, 255}, true)
	end
end

function widgets.slider:onMouseEnter()
	self.mouseIsOver = true
	self:queueRedraw()
end
function widgets.slider:onMouseLeave()
	self.mouseIsOver = false
	self:queueRedraw()
end

function widgets.slider:isMouseInteractable() return true end
function widgets.slider:onMouseButtonEvent(btn, down)
	if down and not self:hasMouse() and self.current then
		self:captureMouse(btn)
		self.changed = false
		self.snap = (btn == 0 or self.snapOnly) -- right click to prevent snapping to notches
		return true
	elseif btn == self:mouseCaptureButton() then
		self.redraw = true
		if self.changed then
			self:onChange(self.current, self.handles[self.current].value)
		end
		self:releaseMouse()
		self:queueRedraw()
		return true
	end
end
function widgets.slider:onCaptureMouseMove(delta)
	if delta[1] == 0 or not self.current or not self.handles[self.current].value then return end

	if not self.changed then
		-- local d = (delta[1] > 0) and 1 or -1
		-- while self.handles[self.current].value == (self.handles[self.current + d] or {}).value and not (self.handles[self.current + d] or {}).locked do
		--	 self.current = self.current + d
		-- end
		self.changed = true
	end

	local f = (self.size[1] - 16) / (self.notches[#self.notches] - self.notches[1])
	local s = self.notches[1] - 8 / f
	local v = self:relativeMousePosition()[1] / f + s

	if self.snap then
		local best = v
		local dist = math.huge
		for i, n in ipairs(self.notches) do
			if math.abs(n - v) < dist then
				best = n
				dist = math.abs(n - v)
			end
		end
		if dist * f < 5 or self.snapOnly then
			v = best
		end
	end

	local min = (self.handles[self.current - 1] or {}).value or self.notches[1]
	local max = (self.handles[self.current + 1] or {}).value or self.notches[#self.notches]
	if v < min then
		v = min
	end
	if v > max then
		v = max
	end

	self.handles[self.current].value = v
	mg.toolTip()
end
function widgets.slider:getToolTip()
	if self.current then
		if self.textToolTips then
			local closest, index = getClosestValue(self.handles[self.current].value, self.notches)
			return self.handles[self.current].toolTip.."\n"..self.textToolTips[index]
		end
		return self.handles[self.current].toolTip .. "\nValue: " .. (math.floor(self.handles[self.current].value * 100 + 0.5) / 100)
	else
		return nil
	end
end

function widgets.slider:onChange(index, value) end

local lastMenu
function mg.dropDownMenu(m, columns, w, h, s, align)
	if type(m) ~= "table" or not m[1] then return nil end -- invalid argument passed
	if lastMenu and lastMenu.dismiss then lastMenu.dismiss() end
	local menuId = "dropDownMenu:" .. sb.makeRandomSource():randu64()
	local cfg = {
		style = "contextMenu", scripts = {"/metagui/sbq/dropDownMenu.lua"}, menuId = menuId,
		forceTheme = mg.cfg.theme, accentColor = mg.cfg.accentColor, -- carry over theme and accent color
		children = { { mode = "vertical", spacing = s or 0 } }
	}
	local height, width = 0, 0
	local hooks = {}
	local rowHeights = {}
	local colWidths = {}

	-- and build
	for i, mi in ipairs(m) do
		if mi == "separator" or mi == "-" then
		elseif type(mi) == "table" then
			local itemId = "item:" .. sb.makeRandomSource():randu64()
			local size = { w or 100, h or 12 }
			if type(mi[1]) == "string" then
				size = vec2.add(mg.measureString(mi[1], w or 100), 4)
				mi[1] = { type = "label", text = mi[1], align = align or "center" }
			end

			local insertRow = math.floor((i-0.1) / columns) + 1
			local insertOffset = 1
			if not cfg.children[insertRow + insertOffset] then
				cfg.children[insertRow + insertOffset] = {}
			end

			rowHeights[insertRow] = math.max((rowHeights[insertRow] or 0), size[2])
			local col = ((i +(columns-1)) % columns) + 1
			colWidths[col] = math.max(colWidths[col] or 0, size[1])

			table.insert(cfg.children[insertRow + insertOffset], {
				type = "menuItem", id = itemId, size = size, children = {
					mi[1]
				}
			})
			local f = mi[2] or function() end
			hooks[itemId] = function() mg.startEvent(f) end
		end
	end
	height = (math.max((h or 0), table.unpack(rowHeights)) + (s or 0)) * #rowHeights
	width = (math.max((w or 0), table.unpack(colWidths)) + (s or 0)) * #colWidths

	local bm = theme.metrics.borderMargins.contextMenu
	cfg.size = {width, height}
	local calcSize = {width + bm[1] + bm[3], height + bm[2] + bm[4]}
	local pushIn = -((bm[1] + bm[2]) / 2 + 2)
	local position = vec2.add(vec2.mul(vec2.add(mg.windowPosition, mg.mousePosition), {1, -1}), {-bm[1] - pushIn, calcSize[2] - bm[2] - pushIn} )

	cfg.anchor = { "bottomLeft",
		{position[1]-(calcSize[1]/2), math.min(0,position[2]-4)}
	}
	theme.modifyContextMenu(cfg) -- give theme a chance to edit whatever it likes
	mg.ipc[menuId] = hooks
	lastMenu = hooks
	player.interact("ScriptPane", { gui = { }, scripts = {"/metagui/sbq/build.lua"}, config = cfg }, 0)
end
mg.registerUninit(function() -- close any paired menus when this pane closes
	if lastMenu and lastMenu.dismiss then lastMenu.dismiss() end
end)

function getClosestValue(x, list)
	local closest
	local closestKey
	local closestDiff = math.huge
	for k, v in ipairs(list) do
		diff = math.abs(v - x)
		if diff <= closestDiff then
			closestDiff = diff
			closest = v
			closestKey = k
		end
	end
	return closest, closestKey
end
