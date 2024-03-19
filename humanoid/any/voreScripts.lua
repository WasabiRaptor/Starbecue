
local Default = {
	states = {
		default = {},
	},
	locations = {}
}
setmetatable(Default, _SpeciesScript)
for k, v in pairs(Default.states) do
	v.__index = v
	setmetatable(v, _State)
end
for k, v in pairs(Default.locations) do
	v.__index = v
	setmetatable(v, _Location)
end
Species.default = Default
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

local function actionSequence(funcName, action, target, actionList, ...)
	local results
	for _, actionData in ipairs(actionList or action.actionList) do
		results = { SpeciesScript[funcName](SpeciesScript, actionData[1], target, table.unpack(actionData[2] or action.args or {})) }
		if action.untilFirstSuccess then
			if results[1] then break end
		else
			if not results[1] then break end
		end
	end
	return table.unpack(results)
end

function default:actionSequence(name, ...)
	return actionSequence("tryAction", ... )
end
function default:actionSequenceAvailable(name, ...)
	return actionSequence("actionAvailable", ... )
end

function default:scriptSequence(name, action, target, scriptList, ...)
	local results
	for _, script in ipairs(scriptList or action.scriptList) do
		results = { self[script](name, action, target, ...) }
		if action.untilFirstSuccess then
			if results[1] then break end
		else
			if not results[1] then break end
		end
    end
	return table.unpack(results)
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
local function letout(funcName, action, target, preferredAction, skip, ...)
	if target then
		occupant = Occupants.entityId[tostring(target)]
		if not occupant then return end
		location = SpeciesScript:getLocation(occupant.location, occupant.subLocation)
		local exitTypes = location.exitTypes or location.entryTypes
		if preferredAction then
			for _, exitType in ipairs(exitTypes or {}) do
				if exitType == preferredAction then
					if SpeciesScript[funcName](SpeciesScript, exitType.."Letout", target) then
						return true
					end
				end
			end
		end
		if skip then return false end
		for _, exitType in ipairs(exitTypes or {}) do
			if SpeciesScript[funcName](SpeciesScript, exitType.."Letout", target) then
				return true
			end
		end
	else
		for i = #Occupants.list, 1, -1 do
			local occupant = Occupants.list[i]
			if SpeciesScript[funcName](SpeciesScript, "letout", occupant.entityId, preferredAction,true) then
				return true
			end
		end
	end
	return false, "invalidAction"
end
function default:letout(name, ...)
	letout("tryAction", ...)
end
function default:letoutAvailable(name, ...)
	letout("actionAvailable", ...)
end

function default:trySendDeeper(name, action, target, ...)
	local location = SpeciesScript:getLocation(action.location)
	local occupant = location.occupancy.list[1]
	local sendDeeper = action.sendDeeper or location.sendDeeper
	if occupant and sendDeeper then
		return sbq.moveToLocation(occupant.entityId, sendDeeper.throughput, sendDeeper.location, sendDeeper.subLocation)
	end
end

function default:grab(name, action, target, ...)
	local location = SpeciesScript:getLocation(action.location or "grabbed")
	if not location then return false end
	local occupant = location.occupancy.list[1]
	if occupant then
		return SpeciesScript:tryAction("grabRelease", occupant.entityId)
	else
		return SpeciesScript:tryAction("grabTarget", target)
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
		local location = SpeciesScript:getLocation(action.location or "grabbed")
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
