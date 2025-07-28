require "/scripts/any/SBQ_util.lua"
function sbq.getActionData(action, available, preferredDirectories, ignoreMissingIcon)
	local shortdescription = sbq.strings.unassignedAction
	local description = sbq.strings.unassignedDesc
	local icon = "/humanoid/any/sbqActionIcons/unassigned.png"

	if action then
		icon = sbq.getActionIcon(action, preferredDirectories or { "/humanoid/any/sbqActionIcons/" }, ignoreMissingIcon)
		shortdescription = sbq.strings[action] or (":" .. action)
		if available then
			description = sbq.strings[action .. "Desc"] or sbq.strings.genericDesc
		else
			description = sbq.strings.unavailableDesc
		end
	end

	return icon, shortdescription, sb.replaceTags(description, { actionName = shortdescription })
end
