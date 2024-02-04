
local Default = {
	states = {
		default = {},
	}
}
setmetatable(Default, _Transformation)
for k, v in pairs(Default.states) do
	setmetatable(v, _State)
end
Transformations.default = Default
Default.__index = Default

function Default:init()
end
function Default:update(dt)
end
function Default:uninit()
end

-- default state scripts
local default = Default.states.default
function default:init()
end
function default:update(dt)
end
function default:uninit()
end

function default:tryVore(name, action, target, ...)
	return sbq.tryVore(target, action.location, action.throughput)
end
function default:tryLetout(name, action, target, ...)
	return sbq.tryLetout(target, action.throughput)
end
function default:pickLetout(name, action, target, preferredAction, skip)
    if target then
        occupant = Occupants.entityId[tostring(target)]
        location = Transformation:getLocation(occupant.location, occupant.subLocation)
        local exitTypes = location.exitTypes or location.entryTypes
		sb.logInfo(sb.printJson(exitTypes))
		if preferredAction then
			for _, exitType in ipairs(exitTypes) do
				if exitType == preferredAction then
					if Transformation:tryAction(exitType.."Letout", target) then
						return true
					end
				end
			end
        end
		if skip then return false end
		for _, exitType in ipairs(exitTypes) do
			if Transformation:tryAction(exitType.."Letout", target) then
				return true
			end
		end
    else
        for i = #Occupants.list, 1, -1 do
            local occupant = Occupants.list[i]
			if Transformation:tryAction("pickLetout",occupant.entityId,preferredAction,true) then
				return true
			end
		end
    end
	return false
end
function default:moveToLocation(name, action, target, location, subLocation)
	return sbq.moveToLocation(target, action.location or location, action.subLocation or subLocation)
end
