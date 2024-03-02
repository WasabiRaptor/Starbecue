---@diagnostic disable: undefined-global

function init()

	widthEntry:setText(tostring(metagui.inputData.size[1]))
	heightEntry:setText(tostring(metagui.inputData.size[2]))
	offsetXEntry:setText(tostring(metagui.inputData.offset[1]))
	offsetYEntry:setText(tostring(metagui.inputData.offset[2]))

	function widthEntry:onEnter() saveSettings() end
	function heightEntry:onEnter() saveSettings() end
	function offsetXEntry:onEnter() saveSettings() end
	function offsetYEntry:onEnter() saveSettings() end
end

function saveSettings()
	local width = tonumber(widthEntry.text) or 1
	local height = tonumber(heightEntry.text) or 1
	local offsetX = tonumber(offsetXEntry.text) or 0
	local offsetY = tonumber(offsetYEntry.text) or 0

	local spaces = {}

	if type(width) == "number" and math.abs(width) > 0
		and type(height) == "number" and math.abs(height) > 0
		and type(offsetX) == "number" and type(offsetY) == "number"
	then
		width = math.abs(math.floor(width))
		height = math.abs(math.floor(height))
		offsetX = math.floor(offsetX)
		offsetY = math.floor(offsetY)
		metagui.inputData.size[1] = width
		metagui.inputData.size[2] = height
		metagui.inputData.offset[1] = offsetX
		metagui.inputData.offset[2] = offsetY
		for x = 0, width-1 do
			for y = 0, height-1 do
				table.insert(spaces, vec2.add({x,y},{offsetX,offsetY}))
			end
		end
		world.sendEntityMessage(pane.sourceEntity(), "saveSettings", spaces, metagui.inputData)
	else
		widthEntry:setText(tostring(metagui.inputData.size[1]))
		heightEntry:setText(tostring(metagui.inputData.size[2]))
		offsetXEntry:setText(tostring(metagui.inputData.offset[1]))
		offsetYEntry:setText(tostring(metagui.inputData.offset[2]))
	end
end
