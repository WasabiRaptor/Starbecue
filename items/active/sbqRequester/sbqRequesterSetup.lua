require "/scripts/any/SBQ_util.lua"
function sbq.getRequestActionData(action, preferredDirectories, ignoreMissingIcon)
	local shortdescription = sbq.strings.unassignedAction
	local description = sbq.strings.unassignedDesc
	local icon = "/humanoid/any/sbqActionIcons/unassigned.png"

	if action then
		icon = sbq.getActionIcon(action, preferredDirectories or { "/humanoid/any/sbqActionIcons/" }, ignoreMissingIcon)
		shortdescription = sbq.strings[action] or (":" .. action)
		description = sbq.strings[action .. "RequestDesc"] or sbq.strings.genericRequestDesc
	end

	return icon, shortdescription, sb.replaceTags(description, { actionName = shortdescription })
end
