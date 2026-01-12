local old = {
	init = init,
	render = render
}
local canvas
local errorString
function init()
	old.init()
	---@diagnostic disable-next-line: undefined-global
	canvas = background.bindCanvas("canvas")
	errorString = root.assetJson("/sbqStrings.config:titleError")
end

function render()
	old.render()
	if errorString and (errorString ~= "") then
		local window = canvas:size()
		canvas:drawText(errorString, {position = {10,window[2]-10}, horizontalAnchor = "left", wrapWidth = window[1]-20}, 12, {255,0,0})
	end
end
