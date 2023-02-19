
local mg = metagui
local widgets = mg.widgetTypes

function widgets.textBox:preferredSize() return self.explicitSize or {96, 14} end
