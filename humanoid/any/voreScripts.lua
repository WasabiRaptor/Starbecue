
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

function default:moveToLocation(name, action, target, locationName, subLocationName, throughput, ...)
	if not target or not (locationName or action.location) then return false, "missingTarget" end
	occupant = Occupants.entityId[tostring(target)]
	if not occupant then return false, "missingOccupant" end
	local location = SpeciesScript:getLocation(locationName or action.location, subLocationName or action.subLocation)
	if not location then return false, "missingLocation" end
	local size = (occupant.size * occupant.sizeMultiplier)
	throughput = throughput or action.throughput
	if throughput or action.throughput then
		if size > (throughput * sbq.scale()) then return false, "tooBig" end
	end
	local space, subLocation = location:hasSpace(size)
	if space then
		occupant.flags.newOccupant = true
		occupant:refreshLocation(locationName, subLocation)
		return true, function ()
			occupant = Occupants.entityId[tostring(target)]
			if occupant then
				occupant.flags.newOccupant = false
				occupant:refreshLocation()
			end
		end
	end
	return false, "noSpace"
end

function default:trySendDeeper(name, action, target, reason, locationName, subLocationName,...)
	local location = SpeciesScript:getLocation(locationName or action.location, subLocationName or action.subLocation)
	if not location then return false, "invalidLocation" end
	local occupant = location.occupancy.list[1]
	if occupant and location.sendDeeperAction then
		return SpeciesScript:tryAction(location.sendDeeperAction.action, occupant.entityId, table.unpack(location.sendDeeperAction.args or {}))
	end
end

function default:voreAvailable(name, action, target, locationName, subLocationName, throughput, ...)
	if not target then return true end
	if target == sbq.loungingIn() then return false, "invalidAction" end
	local loungeAnchor = world.entityCurrentLounge(target)
	if loungeAnchor and (loungeAnchor.entityId ~= entity.id()) and (not loungeAnchor.dismountable) then return false, "invalidAction" end
	local size = sbq.getEntitySize(target)
	if throughput or action.throughput then
		if (size) >= ( throughput or action.throughput * sbq.scale()) then return false, "tooBig" end
	end
	local location = SpeciesScript:getLocation(locationName or action.location, subLocationName or action.subLocation)
	if not location then return false, "invalidLocation" end

	local space, subLocation = location:hasSpace(size)
	if space then
		if (#Occupants.list + 1) <= sbq.config.seatCount then
			return true
		else
			return false, "noSlots"
		end
	else
		return false, "noSpace"
	end
end

function default:tryVore(name, action, target, locationName, subLocationName, throughput, ...)
	if target == sbq.loungingIn() then return false, "invalidAction" end
	local loungeAnchor = world.entityCurrentLounge(target)
	if loungeAnchor and (loungeAnchor.entityId ~= entity.id()) and (not loungeAnchor.dismountable) then return false, "invalidAction" end
	local size = sbq.getEntitySize(target)
	if throughput or action.throughput then
		if (size) >= ( throughput or action.throughput * sbq.scale()) then return false, "tooBig" end
	end
	local location = SpeciesScript:getLocation(locationName or action.location, subLocationName or action.subLocation)
	if not location then return false, "invalidLocation" end
	self:trySendDeeper(name, action, target, nil, locationName, subLocationName)

	local space, subLocation = location:hasSpace(size)
	if space then
		if Occupants.addOccupant(target, size, locationName or action.location, subLocation) then
			world.sendEntityMessage(entity.id(), "sbqControllerRotation", false) -- just to clear hand rotation if one ate from grab
			SpeciesScript.lockActions = true
			return true, function()
				local occupant = Occupants.entityId[tostring(target)]
				if occupant then
					occupant.flags.newOccupant = false
					occupant:refreshLocation()
				end
				SpeciesScript.lockActions = false
			end
		else
			return false, "noSlots"
		end
	else
		return false, "noSpace"
	end
end
function default:tryLetout(name, action, target, throughput, ...)
	local occupant = Occupants.entityId[tostring(target)]
	if not occupant then return false end
	if throughput or action.throughput then
		if (occupant.size * occupant.sizeMultiplier) >= ((throughput or action.throughput) * sbq.scale()) then return false end
	end
	occupant.flags.releasing = true
	occupant.sizeMultiplier = 0 -- so belly expand anims start going down right away
	occupant:getLocation().occupancy.sizeDirty = true
	SpeciesScript.lockActions = true
	return true, function()
		local occupant = Occupants.entityId[tostring(target)]
		SpeciesScript.lockActions = false
		if occupant then occupant:remove() end
	end
end
local function letout(funcName, action, target, preferredAction, ...)
	if target then
		occupant = Occupants.entityId[tostring(target)]
		if not occupant then return end
		location = SpeciesScript:getLocation(occupant.location, occupant.subLocation)
		local exitTypes = location.exitTypes or location.entryTypes

		for _, exitType in ipairs(exitTypes or {}) do
			if (exitType == preferredAction) or (preferredAction == "vore") or (not preferredAction) then
				if SpeciesScript[funcName](SpeciesScript, exitType.."Letout", target) then
					return true
				end
			end
		end
	else
		for i = #Occupants.list, 1, -1 do
			local occupant = Occupants.list[i]
			if SpeciesScript[funcName](SpeciesScript, "letout", occupant.entityId, preferredAction) then
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

function default:grab(name, action, target, ...)
	local location = SpeciesScript:getLocation(action.location)
	if not location then return false end
	local occupant = location.occupancy.list[1]
	if occupant then
		return SpeciesScript:tryAction("grabRelease", occupant.entityId)
	else
		return SpeciesScript:tryAction("grabTarget", target)
	end
end
function default:grabTarget(name, action, target, ...)
	local success, result2 = self:tryVore(name, action, target, ...)
	if success then
		animator.playSound("grab")
		world.sendEntityMessage(entity.id(), "sbqControllerRotation", true)
	end
	return success, result2
end
function default:grabRelease(name, action, target, ...)
	occupant = Occupants.entityId[tostring(target)]
	if not occupant then
		local location = SpeciesScript:getLocation(action.location)
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
	local mainEffect = occupant.locationSettings.mainEffect
	if (not location.mainEffect) or ((not location.mainEffect.digest) and (not location.mainEffect.softDigest)) then return false, "invalidAction" end
	if not ((mainEffect == "digest") or (mainEffect == "softDigest")) then return false, "invalidAction" end
	return true
end
function default:turboDigest(name, action, target, ...)
	if not self:turboDigestAvailable(name, action, target, ...) then return false end
	local occupant = Occupants.entityId[tostring(target)]
	occupant:sendEntityMessage("sbqTurboDigest", sbq.resource("energy"))
	sbq.overConsumeResource("energy", sbq.resourceMax("energy"))
end

function default:turboHealAvailable(name, action, target, ...)
	local occupant = Occupants.entityId[tostring(target)]
	if not occupant then return false, "invalidAction" end
	local location = occupant:getLocation()
	local mainEffect = occupant.locationSettings.mainEffect
	if (not location.mainEffect) or ((not location.mainEffect.heal)) then return false, "invalidAction" end
	if not (mainEffect == "heal") then return false, "invalidAction" end
	return true
end
function default:turboHeal(name, action, target, ...)
	if not self:turboHealAvailable(name, action, target, ...) then return false end
	local occupant = Occupants.entityId[tostring(target)]
	occupant:sendEntityMessage("sbqTurboHeal", sbq.resource("energy"))
	sbq.overConsumeResource("energy", sbq.resourceMax("energy"))
end

function default:digested(name, action, target, ...)
	local occupant = Occupants.entityId[tostring(target)]
	if not occupant then return false end
	local location = occupant:getLocation()
	occupant.flags.digested = true
	occupant.flags.digestedLocation = occupant.location
	occupant.sizeMultiplier = action.sizeMultiplier or location.digestedSizeMultiplier or 1
	occupant.size = action.size or location.digestedSize or 0
	location:markSizeDirty()
	return true, function () occupant:refreshLocation()  end
end

function default:fatal(name, action, target, ...)
	local occupant = Occupants.entityId[tostring(target)]
    if not occupant then return false end
	occupant:modifyResourcePercentage("health", -2)
end

function default:mainEffectAvailable(name, action, target)
	local occupant = Occupants.entityId[tostring(target)]
	if not occupant then return false, "invalidAction" end
	if occupant.locationSettings.mainEffect == (action.mainEffect or name) then return false, "invalidAction" end
	local location = occupant:getLocation()
	if location.mainEffect[action.mainEffect or name] then
		return true
	end
	return false, "invalidAction"
end
function default:setMainEffect(name, action, target)
	local occupant = Occupants.entityId[tostring(target)]
	if not occupant then return false end
	occupant.locationSettings.mainEffect = action.mainEffect or name
	occupant:refreshLocation()
end

function default:reform(name, action, target,...)
	local occupant = Occupants.entityId[tostring(target)]
	if not occupant then return false end
	if occupant:resourcePercentage("health") < 1 then
		occupant.locationSettings.digestedReform = true
		occupant:refreshLocation()
		return false
	end
	local location = occupant:getLocation()
	occupant.flags.infused = false
	occupant.flags.digested = false
	occupant.sizeMultiplier = action.sizeMultiplier or location.reformSizeMultiplier or ((occupant.locationSettings.compression ~= "none") and occupant.locationSettings.compressionMin) or 1
	occupant.size = sbq.getEntitySize(occupant.entityId)
	occupant.locationSettings.mainEffect = action.mainEffect or location.reformMainEffect or "none"
	occupant:refreshLocation()
	location:markSizeDirty()
	return true
end

function default:turboReformAvailable(name, action, target, ...)
	local occupant = Occupants.entityId[tostring(target)]
	if not occupant then return false end
	if not (occupant.locationSettings.digestedReform or occupant.flags.infused) then return false, "invalidAction" end
	return true
end
function default:turboReform(name, action, target, ...)
	if not self:turboReformAvailable(name, action, target, ...) then return false end
	local occupant = Occupants.entityId[tostring(target)]
	occupant:sendEntityMessage("sbqTurboHeal", sbq.resource("energy"))
	sbq.overConsumeResource("energy", sbq.resourceMax("energy"))
end


function default:chooseLocation(name, action, target, predSelect, ...)
	local locations = {}
	local occupant = Occupants.entityId[tostring(target)]
	if not occupant then return false end
	for _, locationName in ipairs(action.locationOrder or sbq.voreConfig.locationOrder or root.assetJson("/sbqGui.config:locationOrder")) do
		local location = SpeciesScript:getLocation(locationName)
		if sbq.tableMatches(location.activeSettings, sbq.settings, true) then
			local space, subLocation = location:hasSpace(occupant.size * occupant.sizeMultiplier)
			table.insert(locations, {
				name = location.name,
				location = locationName,
				subLocation = subLocation,
				space = space
			})
		end
	end
	world.sendEntityMessage( (predSelect and entity.id()) or target, "sbqChooseLocation", entity.id(), target, locations)
end

function default:transform(name, action, target, predSelect, ...)
	local occupant = Occupants.entityId[tostring(target)]
	if not occupant then return false end
	if not ((occupant.flags.digested and (occupant.locationSettings.digestedTransform))
		or ((not occupant.flags.digested) and (occupant.locationSettings.transform)))
	then
		occupant.locationSettings.transform = true
		occupant.locationSettings.digestedTransform = true
		occupant:refreshLocation()
		return false
	elseif (occupant:getPublicProperty("sbqTransformProgress") or 0) < 1 then
	end
	occupant.locationSettings.transform = false
	occupant.locationSettings.digestedTransform = false
	local location = occupant:getLocation()
	occupant:sendEntityMessage("sbqDoTransformation",
		action.transformResult or location.transformResult or { species = humanoid.species() },
		action.transformDuration or location.transformDuration,
		action.transformPerma or location.transformPerma
	)
end
