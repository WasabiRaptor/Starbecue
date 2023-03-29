
theme.listItemColor = "#00000000" -- transparent unless hovered

local hooks = metagui.ipc[metagui.cfg.menuId]
metagui.ipc[metagui.cfg.menuId] = nil -- clean up
hooks.dismiss = function() pane.dismiss() end

local function menuClick(w, btn)
	pane.dismiss()
	hooks[w.id]()
end

for _, w in pairs(paneBase.children) do
	if w.widgetType == "layout" then
		for _, w2 in pairs(w.children) do
			if w2.widgetType == "menuItem" then w2.onClick = menuClick end
		end
	end
end

local mouseRect = rect.pad(rect.withSize({ 0, 0 }, frame.size), 3)
local cdt = 0
function update()
	if not (cdt > 1) then cdt = cdt + script.updateDt() return end
	-- if mouse exits, close
	if not rect.contains(mouseRect, metagui.mousePosition) then
		return pane.dismiss()
	end
end

function uninit()
	hooks.dismiss = nil
end
