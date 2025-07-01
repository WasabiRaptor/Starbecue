function init()
	message.setHandler("saveSettings", function(_, _, spaces, data)
		object.setConfigParameter("coverSpaces", spaces)
		object.setConfigParameter("sbqConfigData", data)
	end)
end

function doorOccupiesSpace(position)
	local relative = { position[1] - object.position()[1], position[2] - object.position()[2] }
	for _, space in ipairs(config.getParameter("coverSpaces") or {{0,0}}) do
		if math.floor(relative[1]) == space[1] and math.floor(relative[2]) == space[2] then
			return true
		end
	end
	return false
end
