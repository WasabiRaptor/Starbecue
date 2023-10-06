function sbq.numberBox(textbox, settingsFunc, settingName, settings, overrideSettings, min, max )
	local value = tonumber(textbox.text)
	local isNumber = type(value) == "number"
	if isNumber and (sbq[overrideSettings] or {})[settingName] == nil then
		local newValue = math.min(math.max(value, (min or -math.huge)), (max or math.huge))
		textbox:setText(tostring(newValue))
		sbq[settingsFunc](settingName, newValue)
		sbq.numberBoxColor(textbox, min, max)
		sbq.saveSettings()
	else
		textbox:setText(tostring((sbq[overrideSettings] or {})[settingName] or (sbq[settings] or {})[settingName] or 0))
	end
end
function sbq.numberBoxColor(textbox, min, max)
	local value = tonumber(textbox.text)
	local isNumber = type(value) == "number"
	local color = "FFFFFF"
	if isNumber then
		if type(max) == "number" and value == max
		or type(min) == "number" and value == min
		then
			color = "FFFF00"
		elseif type(max) == "number" and type(min) == "number" then
			if value > min and value < max then
				color = "00FF00"
			end
		end
		if type(max) == "number" and value > max
		or type(min) == "number" and value < min
		then
			color = "FF0000"
		end
	else
		color = "FF0000"
	end
	textbox:setColor(color)
end
