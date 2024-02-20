
sbq = {
	settingsSetup = {},
	widgetScripts = {},
	getWidget = {},
	settingWidgets = {},
	settings = {}
}
local old = {
	init = init
}
storage = {}

require("/scripts/any/SBQ_RPC_handling.lua")
require("/scripts/any/SBQ_util.lua")

function init()
	sbq.config = root.assetJson("/sbq.config")
	sbq.strings = root.assetJson("/sbqStrings.config")
	sbq.gui = root.assetJson("/sbqGui.config")
	old.init()
end

---@diagnostic disable: undefined-global
local mg = metagui ---@diagnostic disable-line: undefined-global
local widgets = mg.widgetTypes
local mkwidget = mg.mkwidget

local scrollMode = {true,true} -- local thing to the other one, which is dumb
-- first off, modify textBox to actually use given size
function widgets.textBox:preferredSize() return self.explicitSize or { 96, 14 } end

function mg.formatText(str)
    if not str then return nil end
    if str:sub(1, 1) == ":" then
		if sbq.strings then str = sbq.strings[str:sub(2,-1)] or str end
	end
	local colorSub = {
	  ["^accent;"] = string.format("^#%s;", mg.getColor("accent")),
	}
	str = string.gsub(str, "(%b^;)", colorSub)
	return str
end

function mg.setTitle(s)
	mg.cfg.title = mg.formatText(s)
	mg.queueFrameRedraw()
end

widgets.sbqSetting = mg.proto(mg.widgetBase, {
	widgetType = "sbqSetting"
})

function widgets.sbqSetting:init(base, param)
	local defaultSetting = sbq.config.defaultSettings[param.setting]
	if param.location then
		defaultSetting = sbq.config.defaultLocationSettings[param.setting]
	end
	param.toolTip = mg.formatText(param.toolTip or sbq.strings[param.setting.."Tip"])
	local settingType = type(defaultSetting)
	if sbq.gui.settingWidgets[param.setting] then
		param = sb.jsonMerge(param, sbq.gui.settingWidgets[param.setting])
	elseif settingType == "boolean" then
		param = sb.jsonMerge(param, { type = "iconCheckBox", script = "changeSetting" })
	elseif settingType == "table" then
		param = sb.jsonMerge(param, { type = "sbqTextBox", settingType = settingType, script = "changeTableSetting" })
	else
		param = sb.jsonMerge(param, { type = "sbqTextBox", settingType = settingType, script = "changeSetting" })
	end
	self.id = nil
	self.parent:addChild(param)
end

----- modified tabField -----

local tabHeight = 16

local function evContentsTabChanged(self, tab)
	self:setVisible(self.tab == tab)
end

local function evTabSelect(self)
	local tf = self.tab.parent
	local old = tf.currentTab
	tf.currentTab = self.tab
	tf:pushEvent("tabChanged", self.tab, old)
	mg.startEvent(tf.onTabChanged, tf, self.tab, old)

	local subTabs = (tf.subTabs or {})[self.tab.id] or {}
	for i, subTab in ipairs(subTabs) do
		subTab.currentTab.tabWidget:onSelected()
	end

	self.tab:onSelect()
end

function widgets.tabField:update(dt)
end

function widgets.tabField:doUpdate(dt)
	self:update(dt)
	local subTabs = (self.subTabs or {})[(self.currentTab or {}).id] or {}
	for i, subTab in ipairs(subTabs) do
		subTab:doUpdate(dt)
	end
	self.currentTab:update(dt)
end

local tabProto = {}
local tabMt = { __index = tabProto }

function tabProto:setTitle(txt, icon)
	self.titleWidget:setText(txt or tab.id)
	if icon ~= nil then
		self.iconWidget:setFile(icon or nil)
		self.iconWidget:setVisible(not not icon)
	end
end

function tabProto:setColor(c)
	self.tabWidget.color = c
	self.tabWidget:queueRedraw()
end

function tabProto:setVisible(b)
	self.tabWidget:setVisible(b)
end

function tabProto:select()
	self.tabWidget:select()
end

function tabProto:onSelect()
end

function tabProto:update(dt)
end

function widgets.tabField:newTab(param)
	local first = not self.tabScroll.children[1].children[1] -- check if first tab added

	local tab = setmetatable({ parent = self, id = param.id or sb.makeUuid() }, tabMt)
	self.tabs[tab.id] = tab

	-- set up tab widget itself
	tab.tabWidget = self.tabScroll.children[1]:addChild { type = "listItem",
		size = (self.layout == "vertical" and { self.tabWidth, tabHeight } or nil),
		expandMode = self.layout == "vertical" and { 1, 0 } or { 0, 0 }, padding = 0, buttonLike = true,
		visible = param.visible }
	tab.tabWidget.children[1]:addChild { type = "spacer", size = { 0, tabHeight } } -- manual padding
	tab.iconWidget = tab.tabWidget.children[1]:addChild { type = "image", size = { tabHeight, tabHeight }, visible = false }
	tab.titleWidget = tab.tabWidget.children[1]:addChild { type = "label", inline = true }
	tab.tabWidget.children[1]:addChild { type = "spacer", size = { 0, tabHeight } } -- manual padding
	tab.tabWidget.tabStyle = self.layout -- set style var
	tab.tabWidget.color = param.color

	-- populate title and contents
	tab:setTitle(param.title, param.icon)
	tab.contents = mg.createImplicitLayout(param.contents, self.stack, { mode = "vertical", visible = false })

	-- hook up events
	tab.tabWidget.tab = tab
	tab.tabWidget.onSelected = evTabSelect
	tab.contents.tab = tab
	tab.contents:subscribeEvent("tabChanged", evContentsTabChanged)

	if first and not self.noFocusFirstTab then tab:select() end
	return tab
end

----- slider -----

widgets.sbqSlider = mg.proto(mg.widgetBase, {
	expandMode = {1, 0}, -- will expand horizontally, but not vertically
	widgetType = "slider"
})

function widgets.sbqSlider:init(base, param)
	self.expandMode = param.expandMode
	self.textToolTips = param.textToolTips
	self.snapOnly = param.snapOnly
	self.explicitSize = param.size
	self.inverted = param.inverted
	self.percent = param.percent
	self.min = param.min
	self.max = param.max
	self.script = param.script

	if self.script then
		function self:onChange(index, value)
			sbq.widgetScripts[self.script](self.handles[index].setting, value, self.handles[index].location)
		end
	end

	if param.inline then self.expandMode = {0, 0} end
	if param.expand then self.expandMode = {2, 0} end

	self.notches = param.notches or {}
	local min = param.min
	local max = param.max
	if type(param.max) == "string" then
		max = sbq.settings[param.max] or sbq.defaultSettings[param.max] or 1
	end
	if type(param.min) == "string" then
		min = sbq.settings[param.min] or sbq.defaultSettings[param.min] or 0
	end

	if not param.notches and min and max then
		for i = min, max do
			table.insert(self.notches, i)
		end
	end
	if #self.notches < 2 or self.notches[1] >= self.notches[#self.notches] then
		sb.logError("Slider with invalid min/max! id: " .. self.id)
	end

	self.handles = param.handles or {{value = param.value or self.notches[1], toolTip = param.toolTip, locked = param.locked or param.disabled or false}}
	if #self.handles < 1 then
		sb.logError("Slider with no handles! id: " .. self.id)
	end
	for i, h in ipairs(self.handles) do
		if h.setting then
			h.value = sbq.settings[h.setting] or (h.location and sbq.config.defaultLocationSettings[h.setting]) or (sbq.config.defaultSettings[h.setting])
			sbq.settingWidgets[(h.location or "")..h.setting] = self
		end
		if not h.value then
			sb.logError("Slider handle with no value! id: " .. self.id .. ", index: " .. i)
		end
		if self.inverted then
			h.value = (self.notches[#self.notches] - h.value)
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

function widgets.sbqSlider:minSize() return {16, 16} end
function widgets.sbqSlider:preferredSize() return self.explicitSize or {64, 16} end

function widgets.sbqSlider:draw()
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
				if math.abs(d) < dist and true or (math.abs(d) == dist and d > 0) then
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

function widgets.sbqSlider:onMouseEnter()
	self.mouseIsOver = true
	mg.toolTip()
	self:queueRedraw()
end
function widgets.sbqSlider:onMouseLeave()
	self.mouseIsOver = false
	self:queueRedraw()
end

function widgets.sbqSlider:isMouseInteractable() return true end
function widgets.sbqSlider:onMouseButtonEvent(btn, down)
	if down and not self:hasMouse() and self.current then
		self:captureMouse(btn)
		self.changed = false
		self.snap = (btn == 0 or self.snapOnly) -- right click to prevent snapping to notches
		return true
	elseif btn == self:mouseCaptureButton() then
		self.redraw = true
		if self.changed then
			self:onChange(self.current, (self.inverted and (self.notches[#self.notches] - self.handles[self.current].value)) or self.handles[self.current].value)
		end
		self:releaseMouse()
		self:queueRedraw()
		return true
	end
end
function widgets.sbqSlider:onCaptureMouseMove(delta)
	if delta[1] == 0 or not self.current or not self.handles[self.current].value then return end
	if self.handles[self.current].locked then mg.toolTip() return end

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
function widgets.sbqSlider:getToolTip()
	if self.current and self.handles[self.current].toolTip then
		if self.textToolTips then
			local closest, index = getClosestValue(self.handles[self.current].value, self.notches)
			if self.textToolTips[index] then return mg.formatText(self.handles[self.current].toolTip) .. "\n" .. mg.formatText(self.textToolTips[index]) end
		end
		local value = (math.floor(self.handles[self.current].value * 100 + 0.5) / 100)
		if self.percent then
			value = math.floor(value * 100)
		end
		return mg.formatText(self.handles[self.current].toolTip) .. "\n"..sbq.strings.value..": " .. value .. (self.percent and "%" or "")
	else
		return nil
	end
end

function widgets.sbqSlider:onChange(index, value) end

----- fill bar -----

widgets.fillbar = mg.proto(mg.widgetBase, {
	expandMode = {1, 0},
	widgetType = "fillbar"
})

function widgets.fillbar:init(base, param)
	self.expandMode = param.expandMode
	if param.inline then self.expandMode = {0, 0} end
	if param.expand then self.expandMode = {2, 0} end

	self.backingWidget = mkwidget(base, {type = "canvas"})
	self.color = param.color or {200, 100, 100}
	self.background = param.background or {0, 0, 0}
	self.value = param.value or 0.5
	self.max = param.max or 1
end

function widgets.fillbar:minSize() return {16, 8} end
function widgets.fillbar:preferredSize() return { 64, 8 } end

local function subColor(color1, color2)
	return { math.max(color1[1] - color2[1],0), math.max(color1[2] - color2[2],0), math.max(color1[3] - color2[3],0) }
end
local function addColor(color1, color2)
	return { math.min(color1[1] + color2[1], 255), math.min(color1[2] + color2[2],255), math.min(color1[3] + color2[3],255) }
end

function widgets.fillbar:draw()
	local c = widget.bindCanvas(self.backingWidget)
	c:clear()

	local outlineColor = {128, 128, 128}

	c:drawRect({ 1, 0, self.size[1]-1, 1 }, outlineColor)
	c:drawRect({ 1, self.size[2] - 1, self.size[1]-1, self.size[2] }, outlineColor)

	c:drawRect({ 0, 1, 1, self.size[2]-1}, outlineColor)
	c:drawRect({ self.size[1], 1, self.size[1] - 1, self.size[2] - 1 }, outlineColor)

	local fillRect = { 1, 1, math.max(1,(self.size[1] - 1) * self.value / self.max), self.size[2] - 1 }

	c:drawRect({ 1, 1, self.size[1] - 1, self.size[2] - 1 }, self.background)
	c:drawRect(fillRect, subColor(self.color, { 40, 30, 20 }))
	local x1, x2 = math.min(fillRect[1] + 1, fillRect[3]), math.max(fillRect[3] - 1, fillRect[1])
	c:drawRect({ x1, fillRect[2] + 1, x2, fillRect[4] - 1 }, self.color)
	c:drawRect({ x1, fillRect[4]-1, x2, fillRect[4]-2 }, addColor(self.color, {40,30,20}))
end

function widgets.fillbar:setValue(value)
	self.value = value
	self:draw()
end


function widgets.fillbar:isMouseInteractable() return false end
function widgets.fillbar:getToolTip()
	return self.toolTip .. ": " .. self.value .. " / " .. self.max
end

----- icon check box -----

widgets.iconCheckBox = mg.proto(widgets.button, {
	expandMode = { 0, 0 }, -- fixed size
	checked = false,
})

local broadcastLevel = 2
local hRadioFind = {} -- empty table as private event handle
local hRadioValueFind = {}

function widgets.iconCheckBox:init(base, param)
	self.icon = param.icon
	self.state = "idle"
	self.backingWidget = mkwidget(base, { type = "canvas" })
	self.checked = param.checked
	self.radioGroup = param.radioGroup
    self.value = param.value
    self.setting = param.setting
    self.script = param.script
	self.location = param.location


	if self.setting then
		sbq.settingWidgets[(self.location or "") .. self.setting] = self
		local value = sbq.settings[self.setting] or (self.location and sbq.config.defaultLocationSettings[self.setting]) or (sbq.config.defaultSettings[self.setting])
		if type(value) == "boolean" then
			self.checked = value
		end
    end
	if self.script then
		function self:onClick()
			sbq.widgetScripts[self.script](self.setting,self.value or self.checked,self.location)
		end
	end
	self:subscribeEvent("radioButtonChecked", function(self, btn)
		if btn ~= self and btn.radioGroup == self.radioGroup then
			self.checked = false
			self:queueRedraw()
		end
	end)
	self:subscribeEvent(hRadioFind, function(self, group)
		if self.radioGroup == group and self.checked then return self end
	end)
	self:subscribeEvent(hRadioValueFind, function(self, group, val)
		if self.radioGroup == group and self.value == val then return self end
	end)
end

function widgets.iconCheckBox:preferredSize() return { 12, 12 } end

function widgets.iconCheckBox:draw()
	if self.icon then
		local c = widget.bindCanvas(self.backingWidget) c:clear()
		local directives = ""
		if self.state == "press" then directives = "?brightness=-50" end
		local pos = vec2.mul(c:size(), 0.5)

		c:drawImageDrawable(self.icon..directives, pos, 1)
		if self.checked then
			c:drawImageDrawable(self.icon.."?outline=1;FFFFFFFF;FFFFFFFF"..directives, pos, 1)
		end
    else
		theme.drawCheckBox(self)
	end
end

function widgets.iconCheckBox:onMouseEnter()
	self.state = "hover"
	self:queueRedraw()
	--theme.onButtonHover(self)
end

function widgets.iconCheckBox:onMouseButtonEvent(btn, down, shift, cntrl, alt)
	if btn == 0 then -- left button
		if down then
			self.state = "press"
			self:captureMouse(btn)
			self:queueRedraw()
			theme.onCheckBoxClick(self)
		elseif self.state == "press" then
			self.state = "hover"
			if self.radioGroup then
				if not self.checked then
					self.checked = true
					self:wideBroadcast(broadcastLevel, "radioButtonChecked", self)
				end
			else
				self.checked = not self.checked
			end
			self:releaseMouse()
			self:queueRedraw()
			mg.startEvent(self.onClick, self)
		end
		return true
	end
end

function widgets.iconCheckBox:setChecked(b)
	if b and self.radioGroup and not self.checked then
		self.checked = true -- set before event
		self:wideBroadcast(broadcastLevel, "radioButtonChecked", self)
	end
	self.checked = b
	self:queueRedraw()
end

function widgets.iconCheckBox:getGroupChecked()
	if not self.radioGroup then return nil end
	if self.checked then return self end
	return self:wideBroadcast(broadcastLevel, hRadioFind, self.radioGroup)
end

function widgets.iconCheckBox:getGroupValue()
	local c = self:getGroupChecked()
	if c then return c.value end
	return nil -- explicit nil
end

function widgets.iconCheckBox:findValue(val)
	if not self.radioGroup then return nil end
	if self.value == val then return self end
	return self:wideBroadcast(broadcastLevel, hRadioValueFind, self.radioGroup, val)
end

function widgets.iconCheckBox:selectValue(val)
	local c = self:findValue(val)
	if c then c:setChecked(true) end
	return c -- might as well
end

----- other functions -----

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

-- text box ----------------------------------------------------------------------------------------------------------------------------------
widgets.sbqTextBox = mg.proto(mg.widgetBase, {
	expandMode = {1, 0},

	text = "", textWidth = 0,
	caption = "",
	cursorPos = 0,
	scrollPos = 0,
	frameWidth = 4,
})

local ptLast = '^(.*%W+)%w%w-%W-$'
local ptNext = '^%W-%w%w-(%W+.*)$'

function widgets.sbqTextBox:init(base, param)
	self.caption = param.caption
	self.color = param.color

	self.expandMode = param.expandMode
	if param.inline then self.expandMode = {0, 0} end
	if param.expand then self.expandMode = {2, 0} end

	self.backingWidget = mkwidget(base, { type = "canvas" })
    self.subWidgets = { content = mkwidget(base, { type = "canvas" }) }

    self.setting = param.setting
    self.settingType = param.settingType or "string"
    self.script = param.script
    self.location = param.location

	if self.setting then
		sbq.settingWidgets[(self.location or "") .. self.setting] = self
		local value = sbq.settings[self.setting] or (self.location and sbq.config.defaultLocationSettings[self.setting]) or (sbq.config.defaultSettings[self.setting])
		param.text = tostring(value)
		self.settingType = type(value)
		if self.settingType == "table" then
			param.text = sb.printJson(value)
		end
	end

	if self.script then
        function self:onEnter()
			if self.settingType == "number" then
                local number = tonumber(self.text)
				if number then
					sbq.widgetScripts[self.script](self.setting,number,self.location)
                end
            else
				sbq.widgetScripts[self.script](self.setting,tostring(self.text),self.location)
			end
		end
    end
	self:setText(param.text)
end
function widgets.sbqTextBox:preferredSize() return self.explicitSize or {96, 14} end
function widgets.sbqTextBox:draw()
	theme.drawTextBox(self)
	widget.setPosition(self.subWidgets.content, vec2.add(widget.getPosition(self.backingWidget), {self.frameWidth, 0}))
	widget.setSize(self.subWidgets.content, vec2.add(widget.getSize(self.backingWidget), {self.frameWidth*-2, 0}))
	local c = widget.bindCanvas(self.subWidgets.content) c:clear()
	local color = self.focused and "#ffffff" or "#bfbfbf"
	if self.color then
	if type(self.color == "string") then -- hexcode or color name
		color = mg.getColor(self.color:gsub("#", ""))
		color = color and ("#" .. color)
	else color = self.color end -- assume rgb255 table
	end
	local vc = self.size[2]/2
	if self.focused then -- cursor
	local p = mg.measureString(self.text:sub(1, self.cursorPos))[1] - self.scrollPos
	c:drawRect({p, vc-4, p+0.5, vc+4}, '#' .. mg.getColor("accent"))
	elseif self.text == "" then
	c:drawText(self.caption, { position = {0, vc}, horizontalAnchor = "left", verticalAnchor = "mid" }, 8, "#7f7f7f")
	end
	c:drawText(self.text, { position = {-self.scrollPos, vc}, horizontalAnchor = "left", verticalAnchor = "mid" }, 8, color)
end

function widgets.sbqTextBox:isMouseInteractable() return true end
function widgets.sbqTextBox:onMouseButtonEvent(btn, down)
	if btn == 0 and down then
	if not self.focused then
		self:grabFocus()
		self:moveCursor(self.text:len())
	else -- find cursor position from mouse
		local tp = self:relativeMousePosition()[1] + self.scrollPos - self.frameWidth
		local fcp, len = 0, self.text:len()
		for i = 1, len do
		local m = mg.measureString(self.text:sub(1, i))[1]
		if m > tp then break end
		fcp = i
		end
		self:setCursorPosition(fcp)
	end
	return scrollMode[2] and self:captureMouse(btn)
	elseif not down and btn == self:mouseCaptureButton() then
	return self:releaseMouse()
	end
end
function widgets.sbqTextBox:onCaptureMouseMove(delta)
	if delta[1] ~= 0 then
	self:setScrollPosition(self.scrollPos - delta[1])
	end
end
function widgets.sbqTextBox:isWheelInteractable() return scrollMode[1] and self.textWidth > (self.size[1] - self.frameWidth*2) end
function widgets.sbqTextBox:onMouseWheelEvent(dir)
	self:setScrollPosition(self.scrollPos + dir*15)
end

function widgets.sbqTextBox:focus()
	if not self.focused then
	self:grabFocus()
	self:moveCursor(self.text:len())
	end
end
function widgets.sbqTextBox:blur() self:releaseFocus() end

function widgets.sbqTextBox:setText(t)
	local c = self.text
	self.text = type(t) == "string" and t or ""
	if self.text ~= c then
	self.textWidth = mg.measureString(self.text)[1]
	self:queueRedraw()
	mg.startEvent(self.onTextChanged, self)
	end
end
function widgets.sbqTextBox:setColor(c)
	self.color = c
	self:queueRedraw()
end

function widgets.sbqTextBox:setScrollPosition(p)
	self.scrollPos = math.max(0, math.min(p, self.textWidth - (self.size[1] - self.frameWidth * 2) + 1))
	self:queueRedraw()
end
function widgets.sbqTextBox:setCursorPosition(p)
	local c = self.cursorPos
	self.cursorPos = util.clamp(p, 0, self.text:len())
	if self.cursorPos ~= c then
	self:queueRedraw()
	local cw = self.size[1] - self.frameWidth * 2 -- content width
	local cl = cw/2 - 3 -- content limit
	local p = mg.measureString(self.text:sub(1, self.cursorPos))[1] - cw/2
	self:setScrollPosition(util.clamp(self.scrollPos, p-cl, p+cl))
	end
end
function widgets.sbqTextBox:moveCursor(o) self:setCursorPosition(self.cursorPos + o) end

function widgets.sbqTextBox:onFocus() self.focused = true self:queueRedraw() end
function widgets.sbqTextBox:onUnfocus() self.focused = false self:queueRedraw() end
function widgets.sbqTextBox:onKeyEsc() mg.startEvent(self.onEscape, self) end
function widgets.sbqTextBox:acceptsKeyRepeat() return true end
function widgets.sbqTextBox:onKeyEvent(key, down, accel, rep)
	if down then
	if key == mg.keys.enter or key == mg.keys.kpEnter then
		self:releaseFocus()
		mg.startEvent(self.onEnter, self)
	elseif key == mg.keys.left then
		if accel.ctrl then
		local m = self.text:sub(1, self.cursorPos):match(ptLast)
		self:setCursorPosition(m and m:len() or 0)
		else
		self:moveCursor(-1)
		end
	elseif key == mg.keys.right then
		if accel.ctrl then
		local m = self.text:sub(self.cursorPos+1):match(ptNext)
		self:setCursorPosition(m and (self.text:len() - m:len()) or self.text:len())
		else
		self:moveCursor(1)
		end
	elseif key == mg.keys.home then self:setCursorPosition(0)
	elseif key == mg.keys["end"] then self:setCursorPosition(self.text:len())
	elseif key == mg.keys.del then
		if accel.alt then
		self:setText()
		elseif accel.ctrl then
		local m = self.text:sub(self.cursorPos+1):match(ptNext)
		self:setText(self.text:sub(1, self.cursorPos) .. (m or ""))
		else
		self:setText(self.text:sub(1, self.cursorPos) .. self.text:sub(self.cursorPos+2))
		end
	elseif key == mg.keys.backspace then
		if accel.alt then
		self:setText()
		elseif accel.ctrl then
		local m = self.text:sub(1, self.cursorPos):match(ptLast)
		self:setText(self.text:sub(1, m and m:len() or 0) .. self.text:sub(self.cursorPos+1))
		self:setCursorPosition(m and m:len() or 0)
		else
		self:setText(self.text:sub(1, math.max(0, self.cursorPos-1)) .. self.text:sub(self.cursorPos+1))
		self:moveCursor(-1)
		end
	else -- try as printable key
		local char = mg.keyToChar(key, accel)
		if char then
		self:setText(self.text:sub(1, self.cursorPos) .. char .. self.text:sub(self.cursorPos+1))
		self:moveCursor(1)
		end
	end
	--mg.setTitle("key: " .. key)
	end
end

-- events out
function widgets.sbqTextBox:onTextChanged() end
function widgets.sbqTextBox:onEnter() end
function widgets.sbqTextBox:onEscape() end


for id, t in pairs(widgets) do t.widgetType = id end
