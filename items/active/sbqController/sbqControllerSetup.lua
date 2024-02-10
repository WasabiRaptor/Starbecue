function sbq.getActionData(action, available, directory, preferredDirectory)
    local shortdescription = sbq.strings.unassignedAction
    local description = sbq.strings.unassignedActionDesc
	local icon = directory .. "unassigned.png"

    if action then
		icon = sbq.getActionIcon(action, directory, preferredDirectory)
        shortdescription = sbq.strings[action] or (":"..action)
		if available then
			description = sbq.strings[action .. "ActionDesc"] or sbq.strings.genericActionDesc
        else
			description = sbq.strings.unavailableActionDesc
        end
	end

	return icon, shortdescription, sb.replaceTags(description, { actionName = shortdescription })
end

function sbq.getActionIcon(action, directory, preferredDirectory)
	if preferredDirectory and root.assetExists(action..".png", preferredDirectory) then
		return preferredDirectory .. action .. ".png"
	end
	if root.assetExists(action..".png", directory) then
		return directory .. action .. ".png"
	end
	return directory .. "unassigned.png"
end
