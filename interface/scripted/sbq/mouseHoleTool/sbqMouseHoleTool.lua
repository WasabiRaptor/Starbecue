---@diagnostic disable: undefined-global

function init()
	lengthEntry:setText(tostring(metagui.inputData.length))
	horizontalButton:selectValue(metagui.inputData.direction or "h")

	function lengthEntry:onEnter() saveSettings() end
	function horizontalButton:onClick() saveSettings() end
	function verticalButton:onClick() saveSettings() end
end

local directionTable = {
	h = { 1, 0 },
	v = { 0, 1 }
}

function saveSettings()
	local directionVal = horizontalButton:getGroupChecked().value
	local length = tonumber(lengthEntry.text)
	local spaces = {}
	if type(length) == "number" and math.abs(length) > 0 then
		length = math.floor(length)
		metagui.inputData.length = length
		metagui.inputData.direction = directionVal
		local dir = 1
		if length < 0 then
			dir = -1
		end
		for i = 0, math.abs(length)-1 do
			table.insert(spaces, vec2.mul(directionTable[directionVal], i * dir))
		end
		world.sendEntityMessage(pane.sourceEntity(), "saveSettings", spaces, metagui.inputData)
	else
		lengthEntry:setText(tostring(metagui.inputData.length))
	end
end
