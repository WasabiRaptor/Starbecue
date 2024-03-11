
local Default = {
	states = {
		default = {},
    },
	locations = {}
}
setmetatable(Default, _Transformation)
for k, v in pairs(Default.states) do
	v.__index = v
	setmetatable(v, _State)
end
for k, v in pairs(Default.locations) do
	v.__index = v
	setmetatable(v, _Location)
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

function default:actionSequence(name, action, target, actionList, ...)
	for _, actionData in ipairs(actionList or action.actionList) do
        local results = { Transformation:tryAction(actionData[1], target, table.unpack(actionData[2] or action.args or {})) }
        if action.untilFirstSuccess then
			if results[1] then return table.unpack(results) end
        else
			if not results[1] then return table.unpack(results) end
		end
	end
end
function default:scriptSequence(name, action, target, scriptList, ...)
	for _, script in ipairs(scriptList or action.scriptList) do
        local results = { self[script](name, action, target, ...) }
        if action.untilFirstSuccess then
			if results[1] then return table.unpack(results) end
        else
			if not results[1] then return table.unpack(results) end
		end
	end
end

function default:moveToLocation(name, action, target, throughput, location, subLocation, ...)
	return sbq.moveToLocation(target, throughput or action.throughput, action.location or location, action.subLocation or subLocation)
end

function default:tryVore(name, action, target, ...)
	return sbq.tryVore(target, action.location, action.throughput)
end
function default:tryLetout(name, action, target, ...)
	return sbq.tryLetout(target, action.throughput)
end
function default:letout(name, action, target, preferredAction, skip, ...)
    if target then
        occupant = Occupants.entityId[tostring(target)]
		if not occupant then return end
        location = Transformation:getLocation(occupant.location, occupant.subLocation)
        local exitTypes = location.exitTypes or location.entryTypes
		if preferredAction then
			for _, exitType in ipairs(exitTypes or {}) do
				if exitType == preferredAction then
					if Transformation:tryAction(exitType.."Letout", target) then
						return true
					end
				end
			end
        end
		if skip then return false end
		for _, exitType in ipairs(exitTypes or {}) do
			if Transformation:tryAction(exitType.."Letout", target) then
				return true
			end
		end
    else
        for i = #Occupants.list, 1, -1 do
            local occupant = Occupants.list[i]
			if Transformation:tryAction("letout", occupant.entityId, preferredAction,true) then
				return true
			end
		end
    end
	return false
end

function default:trySendDeeper(name, action, target, ...)
    local location = Transformation:getLocation(action.location)
    local occupant = location.occupancy.list[1]
	local sendDeeper = action.sendDeeper or location.sendDeeper
	if occupant and sendDeeper then
		return sbq.moveToLocation(occupant.entityId, sendDeeper.throughput, sendDeeper.location, sendDeeper.subLocation)
	end
end

function default:grab(name, action, target, ...)
    local location = Transformation:getLocation(action.location or "grabbed")
	if not location then return false end
    local occupant = location.occupancy.list[1]
	if occupant then
        return Transformation:tryAction("grabRelease", occupant.entityId)
    else
		return Transformation:tryAction("grabTarget", target)
    end
end
function default:grabTarget(name, action, target, ...)
	local success, result2 = sbq.tryVore(target, action.location or "grabbed", action.throughput or math.huge)
    if success then
		animator.playSound("grab")
        world.sendEntityMessage(entity.id(), "sbqControllerRotation", true)
		return success, result2
	end
end
function default:grabRelease(name, action, target, ...)
    occupant = Occupants.entityId[tostring(target)]
	if not occupant then
		local location = Transformation:getLocation(action.location or "grabbed")
		if not location then return false end
		occupant = location.occupancy.list[1]
	end
    if occupant then
		animator.playSound("release")
        occupant:remove()
		world.sendEntityMessage(entity.id(), "sbqControllerRotation", false)
        return true
    else
		return false
    end
end

function default:turboDigestAvailable(name, action, target, ...)
    local occupant = Occupants.entityId[tostring(target)]
    if not occupant then return false end
    local location = occupant:getLocation()
    local mainEffect = occupant.overrideEffect or location.settings.mainEffect or "none"
	if (not location.mainEffect) or ((not location.mainEffect.digest) and (not location.mainEffect.softDigest)) then return false, "invalidAction" end
	return (mainEffect == "digest") or (mainEffect == "softDigest")
end
function default:turboDigest(name, action, target, ...)
    if not self:turboDigestAvailable(name, action, target, ...) then return false end
    local occupant = Occupants.entityId[tostring(target)]
    occupant:sendEntityMessage("sbqTurboDigest", sbq.resource("energy"))
	sbq.overConsumeResource("energy", sbq.resourceMax("energy"))
end
