---@diagnostic disable: undefined-global
function metagui.theme.drawFrame() -- maybe this could stop the background from drawing
end
local canvas = widget.bindCanvas(frame.backingWidget .. ".canvas")
canvas:clear()
