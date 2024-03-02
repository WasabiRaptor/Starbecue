require"/scripts/any/SBQ_util.lua"
function sbq.getActionData(action, available, directory, preferredDirectory)
    local shortdescription = sbq.strings.unassignedAction
    local description = sbq.strings.unassignedActionDesc
	local icon = "/humanoid/any/sbqActionIcons/unassigned.png"

    if action then
		icon = sbq.getActionIcon(action, preferredDirectory)
        shortdescription = sbq.strings[action] or (":"..action)
		if available then
			description = sbq.strings[action .. "ActionDesc"] or sbq.strings.genericActionDesc
        else
			description = sbq.strings.unavailableActionDesc
        end
	end

	return icon, shortdescription, sb.replaceTags(description, { actionName = shortdescription })
end
