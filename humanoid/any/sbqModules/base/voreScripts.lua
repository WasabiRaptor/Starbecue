
local Default = {
	states = {
		default = {},
	},
	locations = {}
}
setmetatable(Default, sbq._SpeciesScript)
for k, v in pairs(Default.states) do
	v.__index = v
	setmetatable(v, sbq._State)
end
for k, v in pairs(Default.locations) do
	v.__index = v
	setmetatable(v, sbq._Location)
end
sbq.SpeciesScripts.default = Default
Default.__index = Default

function Default:init()
end
function Default:update(dt)
	if status.statPositive("sbq_hideCrotch") then
		self:doAnimations(sbq.voreConfig.hideCrotch)
	else
		self:doAnimations(sbq.voreConfig.showCrotch)
	end
	if status.statPositive("sbq_hideChest") then
		self:doAnimations(sbq.voreConfig.hideChest)
	else
		self:doAnimations(sbq.voreConfig.showChest)
	end
end
function Default:uninit()
end

function Default:settingAnimations()
end

function Default:hideSlots(hideSlots)
	local modifiers = {}
	for k, v in pairs(hideSlots) do
		if v then table.insert(modifiers, {stat = k.."Nude", amount = 1})end
	end
	status.setPersistentEffects("sbqHideSlots", modifiers)
end
function Default:showSlots()
	status.clearPersistentEffects("sbqHideSlots")
end
function Default:refreshStripping()
	if not status.isResource("sbqLust") then return end
	local modifiers = {}
	for _, k in ipairs({"head","chest","legs","back"}) do
		if status.resourcePercentage("sbqLust") > sbq.settings.read[k.."Strip"] then
			table.insert(modifiers, {stat = k.."Nude", amount = 1})
		end
	end
	status.setPersistentEffects("sbqStripping", modifiers)
	sbq.SpeciesScript:settingAnimations()
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
	local successCount = 0
	local results
	local actions = actionList or action.actionList
	if action.randomizeOrder then
		actions = {}
		for _, v in ipairs(actionList or action.actionList) do
			table.insert(actions, math.random(#actions + 1), v)
		end
	end
	for _, actionData in ipairs(actions) do
		if (target and action.untilFirstSuccess) and not sbq.SpeciesScript:actionAvailable(actionData[1], nil, table.unpack(actionData[2] or action.args or {}) ) then
		else
			results = { sbq.SpeciesScript:tryAction(actionData[1], target, table.unpack(actionData[2] or action.args or {})) }
			if results[1] then
				successCount = successCount + 1
				if (action.successCount) then
					if (successCount >= (action.successCount)) then
						break
					else
						results = {false, "invalidAction"}
					end
				elseif action.untilFirstSuccess then
					break
				end
			elseif not action.untilFirstSuccess then
				break
			end
		end
	end
	return table.unpack(results or {})
end

function default:actionSequenceAvailable(name, action, target, actionList, ...)
	local successCount = 0
	local results
	local actions = actionList or action.actionList
	for _, actionData in ipairs(actions) do
		if (target and action.untilFirstSuccess) and not sbq.SpeciesScript:actionAvailable(actionData[1], nil, table.unpack(actionData[2] or action.args or {}) ) then
		else
			results = {sbq.SpeciesScript:actionAvailable(actionData[1], target, table.unpack(actionData[2] or action.args or {}))}
			if results[1] then
				successCount = successCount + 1
				if (action.availableSuccessCount or action.successCount) then
					if (successCount >= (action.availableSuccessCount or action.successCount)) then
						break
					else
						results = {false, "invalidAction"}
					end
				elseif action.untilFirstSuccess then
					break
				end
			elseif not action.untilFirstSuccess then
				break
			end
		end
	end
	return table.unpack(results or {})
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
	occupant = sbq.Occupants.entityId[tostring(target)]
	if not occupant then return false, "missingOccupant" end
	local location = sbq.SpeciesScript:getLocation(locationName or action.location, subLocationName or action.subLocation)
	if not location then return false, "invalidLocation" end
	local size = (occupant.size * occupant.sizeMultiplier)
	throughput = throughput or action.throughput
	if throughput and not location.settings.hammerspace then
		if size > (throughput * sbq.getScale()) then return false, "tooBig" end
	end
	local space, subLocation = location:hasSpace(size)
	if space then
		location:queueSizeChangeAnims(action.sizeChangeAnims)
		if action.forceSizeRefresh then
			location:markSizeDirty(true)
		end

		occupant:refreshLocation(locationName or action.location, subLocation)
		location:refreshStruggleDirection()
		return true, function ()
			occupant = sbq.Occupants.entityId[tostring(target)]
			if occupant then
				occupant:refreshLocation()
				location:refreshStruggleDirection()
				if action.sizeChangeAnims then
					location:clearQueuedSizeChangeAnims()
				end
			end
		end
	end
	return false, "noSpace"
end
function default:moveToLocationAvailable(name, action, target, locationName, subLocationName, throughput, ...)
	occupant = sbq.Occupants.entityId[tostring(target)]
	if not occupant then return false, "missingOccupant" end
	local location = sbq.SpeciesScript:getLocation(locationName or action.location, subLocationName or action.subLocation)
	if not location then return false, "invalidLocation" end
	local size = (occupant.size * occupant.sizeMultiplier)
	throughput = throughput or action.throughput
	if throughput and not location.settings.hammerspace then
		if size > (throughput * sbq.getScale()) then return false, "tooBig" end
	end
	local space, subLocation = location:hasSpace(size)
	if space then
		return true
	end
	return false, "noSpace"
end

function default:trySendDeeperAvailable(name, action, target, failureReason, size, ...)
	if target then
		local occupant = sbq.Occupants.entityId[tostring(target)]
		if not occupant then return false, "missingOccupant" end
		local location = occupant:getLocation()
		if not location.sendDeeperAction then return false, "invalidAction" end
		if not occupant:active() then return false, "invalidAction" end
		return sbq.SpeciesScript:actionAvailable(location.sendDeeperAction.action, target, table.unpack(location.sendDeeperAction.args or {}))
	else
		local location = sbq.SpeciesScript:getLocation(action.location, action.subLocation)
		if not location then return false, "invalidLocation" end
		if not location.sendDeeperAction then return false, "invalidAction" end
		local spaceNeeded = (size * location.settings.multiplyFill / sbq.getScale()) - location:getRemainingSpace()
		local success, newFailureReason
		for _, occupant in ipairs(location.occupancy.list) do
			success, newFailureReason = self:trySendDeeperAvailable(name, action, occupant.entityId)
			if success then
				local occupantSize = occupant.size * occupant.sizeMultiplier * location.settings.multiplyFill / sbq.getScale()
				if (failureReason == "noSpace") and (type(size) == "number") then
					if spaceNeeded <= occupantSize then break end
				else
					break
				end
			end
		end
		return success, newFailureReason
	end
end

function default:trySendDeeper(name, action, target, failureReason, size, ...)
	if target then
		local occupant = sbq.Occupants.entityId[tostring(target)]
		if not occupant then return false, "missingOccupant" end
		local location = occupant:getLocation()
		if not location.sendDeeperAction then return false, "invalidAction" end
		if not occupant:active() then return false, "invalidAction" end
		return sbq.SpeciesScript:tryAction(location.sendDeeperAction.action, occupant.entityId, table.unpack(location.sendDeeperAction.args or {}))
	else
		local location = sbq.SpeciesScript:getLocation(action.location, action.subLocation)
		if not location then return false, "invalidLocation" end
		if not location.sendDeeperAction then return false, "invalidAction" end
		local success, newFailureReason
		location:safeIterateOccupants(function (occupant)
			success, newFailureReason = self:trySendDeeper(name, action, occupant.entityId)
			location:updateOccupancy(0) -- we need to refresh the size immediately for space calculations
			if success then
				if (failureReason == "noSpace") and (type(size) == "number") then
					local space, subLocation = location:hasSpace(size)
					if space then return true end
				else
					return true
				end
			end
		end)
		return success, newFailureReason
	end
end

function default:voreAvailable(name, action, target, locationName, subLocationName, throughput, ...)
	if status.statPositive("sbqIsPrey") or status.statPositive("sbqEntrapped") then return false, "nested" end
	local size
	if target then
		if (target == sbq.loungingIn()) then return false, "invalidAction" end
		local loungeId, anchorIndex = world.entity(target):anchorState()
		if loungeId and (loungeId ~= entity.id()) and (not world.entity(loungeId):loungeAnchor(anchorIndex).dismountable) then return false, "invalidAction" end
		size = sbq.getEntitySize(target)
	end
	local location = sbq.SpeciesScript:getLocation(locationName or action.location, subLocationName or action.subLocation)
	if not location then return false, "invalidLocation" end
	if location.activeSettings then
		if not sbq.settings:matches(location.activeSettings, true) then
			if location.infuseType then
				if not (action.flags and action.flags.infusing) then
					return false, "needsInfusion"
				end
			else
				return false, "invalidLocation"
			end
		end
	end
	if location.disabled then
		if location.infuseType then
			if not (action.flags and action.flags.infusing) then
				return false, "needsInfusion"
			end
		else
			return false, "invalidLocation"
		end
	end
	if not target then return true end
	throughput = throughput or action.throughput
	if throughput and not location.settings.hammerspace then
		if size > (throughput * sbq.getScale()) then return false, "tooBig" end
	end

	local space, subLocation = location:hasSpace(size)

	if not space and location.sendDeeperAction then
		if self:trySendDeeperAvailable(name, action, nil, "noSpace", size) then
			space = size
		end
	end

	if space or (action.flags and action.flags.infusing) then
		if (#sbq.Occupants.list + 1) <= sbq.voreConfig.seatCount then
			return true
		else
			return false, "noSlots"
		end
	else
		return false, "noSpace"
	end
end

function default:tryVore(name, action, target, ...)
	if status.statPositive("sbqIsPrey") or status.statPositive("sbqEntrapped") then return false, "nested" end
	if target == sbq.loungingIn() then return false, "invalidAction" end
	local loungeId, anchorIndex = world.entity(target):anchorState()
	if loungeId and (loungeId ~= entity.id()) and (not world.entity(loungeId):loungeAnchor(anchorIndex).dismountable) then return false, "invalidAction" end
	local size = sbq.getEntitySize(target)
	local location = sbq.SpeciesScript:getLocation(action.location, action.subLocation)
	if not location then return false, "invalidLocation" end
	if location.activeSettings then
		if not sbq.settings:matches(location.activeSettings, true) then
			if location.infuseType then
				if not (action.flags and action.flags.infusing) then
					return false, "needsInfusion"
				end
			else
				return false, "invalidLocation"
			end
		end
	end
	if location.disabled then
		if location.infuseType then
			if not (action.flags and action.flags.infusing) then
				return false, "needsInfusion"
			end
		else
			return false, "invalidLocation"
		end
	end
	throughput = throughput or action.throughput
	if throughput and not location.settings.hammerspace then
		if size > (throughput * sbq.getScale()) then return false, "tooBig" end
	end


	local space, subLocation = location:hasSpace(size)

	if not space and location.sendDeeperAction then
		self:trySendDeeper(name, action, nil, "noSpace", size)
		space, subLocation = location:hasSpace(size)
	end

	if space or (action.flags and action.flags.infusing) then
		location:queueSizeChangeAnims(action.sizeChangeAnims)
		location:lockSize(action.lockSize)
		local function finished()
			if action.lockSize then
				location:unlockSize()
				location:markSizeDirty()
			end
			if action.sizeChangeAnims then
				location:clearQueuedSizeChangeAnims()
			end
			sbq.SpeciesScript.lockActions = false
		end
		if sbq.Occupants.newOccupant(target, size, action.location, subLocation, action.flags) then
			if action.forceSizeRefresh then
				location:markSizeDirty(true)
			end
			world.sendEntityMessage(entity.id(), "sbqControllerRotation", false) -- just to clear hand rotation if one ate from grab
			sbq.SpeciesScript.lockActions = true
			sbq.SpeciesScript:hideSlots(action.hideSlots or {})
			sbq.SpeciesScript:settingAnimations()
			return true, function()
				sbq.forceTimer(name.."ShowCosmeticAnims", 5, function ()
					sbq.SpeciesScript:showSlots()
					sbq.SpeciesScript:settingAnimations()
				end)
				local occupant = sbq.Occupants.entityId[tostring(target)]
				if occupant then
					occupant.flags.newOccupant = false
					occupant:refreshLocation()
				end
				finished()
			end
		else
			finished()
			return false, "noSlots"
		end
	else
		return false, "noSpace"
	end
end
function default:tryLetout(name, action, target, throughput, ...)
	if status.statPositive("sbqIsPrey") or status.statPositive("sbqEntrapped") then return false, "nested" end
	local occupant = sbq.Occupants.entityId[tostring(target)]
	if not occupant then return false, "missingOccupant" end
	throughput = throughput or action.throughput
	if throughput and not occupant.locationSettings.hammerspace then
		if (occupant.size * occupant.sizeMultiplier) > (throughput * sbq.getScale()) then return false, "tooBig" end
	end
	if occupant.flags.digested or occupant.flags.infused or occupant.flags.digesting then return false, "invalidAction" end
	local location = occupant:getLocation()
	if action.location then
		location = sbq.SpeciesScript:getLocation(action.location, action.subLocation)
	end
	if not location then return false, "invalidLocation" end
	location:queueSizeChangeAnims(action.sizeChangeAnims)
	location:lockSize(action.lockSize)
	location:markSizeDirty(action.forceSizeRefresh)
	occupant.flags.releasing = true
	sbq.SpeciesScript.lockActions = true
	sbq.SpeciesScript:hideSlots(action.hideSlots or {})
	sbq.SpeciesScript:settingAnimations()
	sbq.forceTimer("huntTargetSwitchCooldown", 30)
	return true, function()
		if action.lockSize then
			location:unlockSize()
			location:markSizeDirty()
		end
		if action.sizeChangeAnims then
			location:clearQueuedSizeChangeAnims()
		end
		sbq.SpeciesScript.lockActions = false

		sbq.forceTimer(name.."ShowCosmeticAnims", 5, function ()
			sbq.SpeciesScript:showSlots()
			sbq.SpeciesScript:settingAnimations()
		end)
		sbq.forceTimer("huntTargetSwitchCooldown", 30)
		local occupant = sbq.Occupants.entityId[tostring(target)]
		if occupant then occupant:remove("releasing") end
	end
end
local function letout(funcName, action, target, preferredActions, ...)
	if status.statPositive("sbqIsPrey") or status.statPositive("sbqEntrapped") then return false, "nested" end
	if target then
		occupant = sbq.Occupants.entityId[tostring(target)]
		if not occupant then return end
		location = occupant:getLocation()
		local exitTypes = location.exitTypes or location.entryTypes

		for _, exitType in ipairs(exitTypes or {}) do
			if not preferredActions then
				if sbq.SpeciesScript[funcName](sbq.SpeciesScript, exitType.."Letout", target) then
					return true
				end
			else
				for _, preferredAction in ipairs(preferredActions) do
					if (exitType == preferredAction) or (preferredAction == "vore") then
						if sbq.SpeciesScript[funcName](sbq.SpeciesScript, exitType.."Letout", target) then
							return true
						end
					end
				end
			end
		end
	else
		for i = #sbq.Occupants.list, 1, -1 do
			local occupant = sbq.Occupants.list[i]
			if sbq.SpeciesScript[funcName](sbq.SpeciesScript, "letout", occupant.entityId, preferredActions) then
				return true
			end
		end
		for i = #sbq.Occupants.list, 1, -1 do
			local occupant = sbq.Occupants.list[i]
			if sbq.SpeciesScript[funcName](sbq.SpeciesScript, "letout", occupant.entityId) then
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
	local location = sbq.SpeciesScript:getLocation(action.location)
	if not location then return false, "invalidLocation" end
	local occupant = location.occupancy.list[1]
	if occupant then
		return sbq.SpeciesScript:tryAction("grabRelease", occupant.entityId)
	else
		return sbq.SpeciesScript:tryAction("grabTarget", target)
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
	occupant = sbq.Occupants.entityId[tostring(target)]
	if not occupant then
		local location = sbq.SpeciesScript:getLocation(action.location)
		if not location then return false, "invalidLocation" end
		occupant = location.occupancy.list[1]
	end
	if occupant then
		animator.playSound("release")
		occupant:remove("releasing")
		world.sendEntityMessage(entity.id(), "sbqControllerRotation", false)
		return true
	else
		return false, "missingOccupant"
	end
end

function default:turboDigestAvailable(name, action, target, ...)
	local occupant = sbq.Occupants.entityId[tostring(target)]
	if not occupant then return false, "missingOccupant" end
	local location = occupant:getLocation()
	local mainEffect = occupant.locationSettings.mainEffect
	if (not location.mainEffect) or ((not location.mainEffect.digest) and (not location.mainEffect.softDigest)) then return false, "invalidAction" end
	if not ((mainEffect == "digest") or (mainEffect == "softDigest")) then return false, "invalidAction" end
	return true
end
function default:turboDigest(name, action, target, ...)
	if not self:turboDigestAvailable(name, action, target, ...) then return false, "invalidAction" end
	local occupant = sbq.Occupants.entityId[tostring(target)]
	occupant:sendEntityMessage("sbqTurboDigest", status.resource("energy"))
	status.overConsumeResource("energy", status.resourceMax("energy"))
end

function default:turboHealAvailable(name, action, target, ...)
	local occupant = sbq.Occupants.entityId[tostring(target)]
	if not occupant then return false, "invalidAction" end
	local location = occupant:getLocation()
	local mainEffect = occupant.locationSettings.mainEffect
	if (not location.mainEffect) or ((not location.mainEffect.heal)) then return false, "invalidAction" end
	if not (mainEffect == "heal") then return false, "invalidAction" end
	return true
end
function default:turboHeal(name, action, target, ...)
	if not self:turboHealAvailable(name, action, target, ...) then return false, "invalidAction" end
	local occupant = sbq.Occupants.entityId[tostring(target)]
	occupant:sendEntityMessage("sbqTurboHeal", status.resource("energy"))
	status.overConsumeResource("energy", status.resourceMax("energy"))
end

function default:digested(name, action, target, item, digestType, drop, ...)
	local occupant = sbq.Occupants.entityId[tostring(target)]
	local location
	local delay = 0
	if occupant then
		location = occupant:getLocation()
		occupant.flags.digesting = true
		occupant.flags.digestedLocation = occupant.location
		occupant.flags.digestType = digestType
		occupant.sizeMultiplier = action.sizeMultiplier or location.digestedSizeMultiplier or 1
		occupant.size = action.size or location.digestedSize or 0
		occupant:refreshLocation()
		sbq.addRPC(occupant:sendEntityMessage("sbqDumpOccupants", occupant.location, occupant.subLocation, digestType), sbq.receiveOccupants)
	end
	if location then
		location:markSizeDirty()
		local sizeChangeAnims = location.occupancy.queuedSizeChangeAnims or location.sizeChangeAnims
		if sizeChangeAnims then
			delay = sbq.SpeciesScript:checkAnimations(false, sizeChangeAnims, {})
		end
		if location.digestedAnims then
			delay = math.max(delay, sbq.SpeciesScript:checkAnimations(false, location.digestedAnims, {}, target))
		end
	end
	if not sbq.Occupants.checkActiveOccupants() then sbq.SpeciesScript:queueAction("lockDownClear") end
	sbq.timer(target .. "Digesting", delay, function()
		local occupant = sbq.Occupants.entityId[tostring(target)]
		local position = entity.position()
		if occupant then
			position = occupant:position()
			occupant.flags.digesting = false
			occupant.flags.digested = true
			occupant:refreshLocation()
		end
		if item and item.parameters then
			item.parameters.predName = sbq.entityName(entity.id())
			item.parameters.predUuid = entity.uniqueId()
			item.parameters.predPronouns = sbq.getPublicProperty(entity.id(), "sbqPronouns")
			if humanoid then
				item.parameters.predIdentity = sbq.humanoidIdentity()
			end
			if item.name and sbq.settings:get(digestType.."Drops") and drop then
				world.spawnItem(item, position)
			end
			-- we can drop condoms and milk for monsters, but if we don't have NPC data theres no reason to preserve it
			if not item.parameters.npcArgs then return end
			item.name = "sbqNPCEssenceJar"
			if not storage.sbqRecentlyDigested then
				storage.sbqRecentlyDigested = jarray()
			end
			table.insert(storage.sbqRecentlyDigested, 1, item)
			while #storage.sbqRecentlyDigested > sbq.config.recentlyDigestedCount do
				table.remove(storage.sbqRecentlyDigested, #storage.sbqRecentlyDigested)
			end
		end
	end)
	return true
end

function default:fatalAvailable(name, action, target, ...)
	local occupant = sbq.Occupants.entityId[tostring(target)]
	if not occupant then return false, "missingOccupant" end
	if not occupant.flags.digested then return false, "invalidAction" end
	if not occupant.flags.digestType then return false, "invalidAction" end
	if occupant:statPositive("sbq_" .. (occupant.flags.digestType) .. "FatalImmune") then return false, "invalidAction" end
	if sbq.settings:checkInvalid("mainEffect", "digest", "locations", occupant.location) ~= ("digest") then return false, "invalidAction" end
	return true
end
function default:fatal(name, action, target, ...)
	local occupant = sbq.Occupants.entityId[tostring(target)]
	if not occupant then return false, "missingOccupant" end
	if not occupant.flags.digested then return false, "invalidAction" end
	if not occupant.flags.digestType then return false, "invalidAction" end
	if occupant:statPositive("sbq_" .. (occupant.flags.digestType) .. "FatalImmune") then return false, "invalidAction" end
	if sbq.settings:checkInvalid("mainEffect", "digest", "locations", occupant.location) ~= ("digest") then return false, "invalidAction" end
	occupant.persistentStatusEffects = {
		{ stat = "healingBonus", amount = -10 },
		{ stat = "healingStatusImmunity", amount = 999 },
		{ stat = "healthRegen", effectiveMultiplier = 0 },
		{ stat = "energyRegenPercentageRate", effectiveMultiplier = 0 }
	}
	occupant:refreshLocation()
	occupant:modifyResourcePercentage("health", -2)
	return true
end

function default:mainEffectAvailable(name, action, target)
	local occupant = sbq.Occupants.entityId[tostring(target)]
	if not occupant then return false, "invalidAction" end
	if occupant.locationSettings.mainEffect == (action.mainEffect or name) then return false, "invalidAction" end
	if sbq.settings:checkInvalid("mainEffect", action.mainEffect or name, "locations", occupant.location) ~= (action.mainEffect or name) then return false, "invalidAction" end
	local location = occupant:getLocation()
	if location.mainEffect[action.mainEffect or name] then
		return true
	end
	return false, "invalidAction"
end
function default:setMainEffect(name, action, target)
	local occupant = sbq.Occupants.entityId[tostring(target)]
	if not occupant then return false, "missingOccupant" end
	if sbq.settings:checkInvalid("mainEffect", action.mainEffect or name, "locations", occupant.location) ~= (action.mainEffect or name) then return false, "invalidAction" end
	occupant.locationSettings.mainEffect = action.mainEffect or name
	occupant:refreshLocation()
end

function default:reform(name, action, target,...)
	local occupant = sbq.Occupants.entityId[tostring(target)]
	if not occupant then return false, "missingOccupant" end
	if occupant:resourcePercentage("health") < 1 then
		occupant.locationSettings.reformDigested = true
		occupant:refreshLocation()
		return true
	else
		return sbq.SpeciesScript:tryAction("reformed", target)
	end
end
function default:reformed(name, action, target,...)
	local occupant = sbq.Occupants.entityId[tostring(target)]
	if not occupant then return false, "missingOccupant" end
	local location = occupant:getLocation()
	if occupant.flags.infused then
		location.infusedEntity = nil
		sbq.settings:setParameterSettings()
	end
	occupant.flags.infuseType = nil
	occupant.flags.infused = false
	occupant.flags.infuseSlots = nil
	occupant.flags.digesting = false
	occupant.flags.digested = false
	occupant.sizeMultiplier = action.sizeMultiplier or location.reformSizeMultiplier or ((occupant.locationSettings.compression ~= "none") and occupant.locationSettings.compressionMin) or 1
	occupant.size = sbq.getEntitySize(occupant.entityId)
	occupant.locationSettings.mainEffect = action.mainEffect or location.reformMainEffect or "none"
	occupant:refreshLocation()
	location:markSizeDirty()
	return true
end

function default:turboReformAvailable(name, action, target, ...)
	local occupant = sbq.Occupants.entityId[tostring(target)]
	if not occupant then return false, "missingOccupant" end
	if not (occupant.locationSettings.reformDigested or occupant.flags.infused) then return false, "invalidAction" end
	return true
end
function default:turboReform(name, action, target, ...)
	if not self:turboReformAvailable(name, action, target, ...) then return false, "invalidAction" end
	local occupant = sbq.Occupants.entityId[tostring(target)]
	occupant:sendEntityMessage("sbqTurboHeal", status.resource("energy"))
	status.overConsumeResource("energy", status.resourceMax("energy"))
end


function default:chooseLocation(name, action, target, predSelect, ...)
	local locations = {}
	local occupant = sbq.Occupants.entityId[tostring(target)]
	if not occupant then return false, "missingOccupant" end
	for _, locationName in ipairs(action.locationOrder or sbq.voreConfig.locationOrder or root.assetJson("/sbqGui.config:locationOrder")) do
		local location = sbq.SpeciesScript:getLocation(locationName)
		if location and sbq.settings:matches(location.activeSettings, true) then
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

function default:transformAvailable(name, action, target, ...)
	local occupant = sbq.Occupants.entityId[tostring(target)]
	if not occupant then return false, "missingOccupant" end
	local location = occupant:getLocation()
	local transformResult = sb.jsonMerge({species = sbq.species()}, sbq.voreConfig.transformResult or {}, action.transformResult or {}, location.transformResult or {})
	local transformDuration = action.transformDuration or location.transformDuration or sbq.voreConfig.transformDuration or sbq.config.defaultVoreTFDuration
	if not transformResult then return false, "invalidAction" end
	local checkSettings = {
		speciesTF = transformResult.species and true,
		genderTF = transformResult.gender and true
	}
	if not sbq.tableMatches(checkSettings, sbq.getPublicProperty(target, "sbqPublicSettings")) then return false, "targetSettingsMismatch" end
	return true
end
function default:transform(name, action, target, ...)
	local occupant = sbq.Occupants.entityId[tostring(target)]
	if not occupant then return false, "missingOccupant" end
	local location = occupant:getLocation()
	local transformResult = sb.jsonMerge({species = sbq.species()}, sbq.voreConfig.transformResult or {}, action.transformResult or {}, location.transformResult or {})
	local transformDuration = action.transformDuration or location.transformDuration or sbq.voreConfig.transformDuration or 10
	if not transformResult then return false, "invalidAction" end
	local checkSettings = {
		speciesTF = transformResult.species and true,
		genderTF = transformResult.gender and true
	}
	if not sbq.tableMatches(checkSettings, sbq.getPublicProperty(target, "sbqPublicSettings")) then return false, "targetSettingsMismatch" end

	if not occupant.flags.transformed then
		occupant.locationSettings.transform = true
		occupant.locationSettings.transformDigested = true
		occupant:refreshLocation()
		return true
	end
end
function default:transformed(name, action, target, ...)
	local occupant = sbq.Occupants.entityId[tostring(target)]
	if not occupant then return false, "missingOccupant" end
	local location = occupant:getLocation()
	local transformResult = sb.jsonMerge({species = sbq.species()}, sbq.voreConfig.transformResult or {}, action.transformResult or {}, location.transformResult or {})
	local transformDuration = action.transformDuration or location.transformDuration or sbq.voreConfig.transformDuration or 10
	if not transformResult then return false, "invalidAction" end
	local checkSettings = {
		speciesTF = transformResult.species and true,
		genderTF = transformResult.gender and true
	}
	if not sbq.tableMatches(checkSettings, sbq.getPublicProperty(target, "sbqPublicSettings")) then return false, "targetSettingsMismatch" end

	transformResult.gender = transformResult.gender or occupant.locationSettings.transgender

	occupant.flags.transformed = true
	occupant.locationSettings.transform = false
	occupant.locationSettings.transformDigested = false
	occupant:sendEntityMessage("sbqDoTransformation", transformResult, transformDuration)
	return true
end

function default:infuseAvailable(name, action, target, ...)
	local location = sbq.SpeciesScript:getLocation(action.location)
	if not location then return false, "invalidLocation" end
	if location.infusedEntity and sbq.Occupants.entityId[tostring(location.infusedEntity)]then return false, "alreadyInfused" end

	local occupant = sbq.Occupants.entityId[tostring(target)]
	if occupant then
		return true
	else
		return sbq.SpeciesScript:actionAvailable(action.voreAction, target)
	end
end
function default:tryInfuse(name, action, target, ...)
	local location = sbq.SpeciesScript:getLocation(action.location)
	if not location then return false, "invalidLocation" end
	local infuseType = action.infuseType or location.infuseType or name
	if location.infusedEntity and sbq.Occupants.entityId[tostring(location.infusedEntity)] then return false, "alreadyInfused" end
	local occupant = sbq.Occupants.entityId[tostring(target)]
	if occupant then
		occupant.locationSettings[infuseType.."Digested"] = true
		occupant.locationSettings[infuseType] = true
		occupant:refreshLocation()
		return true
	else
		local res = { sbq.SpeciesScript:tryAction(action.voreAction, target) }
		if res[1] then
			sbq.SpeciesScript:queueAction(action.finishAction or name, target)
		end
		return table.unpack(res)
	end
end
function default:infused(name, action, target)
	local location = sbq.SpeciesScript:getLocation(action.location)
	if not location then return false, "invalidLocation" end
	local infuseType = action.infuseType or location.infuseType or name
	local occupant = sbq.Occupants.entityId[tostring(target)]
	if not occupant then return false, "missingOccupant" end
	if location.infusedEntity and sbq.Occupants.entityId[tostring(location.infusedEntity)] then
		occupant.locationSettings[infuseType.."Digested"] = false
		occupant.locationSettings[infuseType] = false
		occupant:refreshLocation()
		return false, "alreadyInfused"
	end
	location.infusedEntity = target
	occupant.flags.digested = false
	occupant.flags.digesting = false
	occupant.flags.infused = true
	occupant.flags.infuseSlots = copyArray(action.infuseSlots)
	occupant.flags.infusing = false
	occupant.flags.infuseType = infuseType
	occupant.locationSettings[infuseType.."Digested"] = false
	occupant.locationSettings[infuseType] = false
	local locationName = occupant.location
	local subLocationName = occupant.subLocation
	if not sbq.Occupants.checkActiveOccupants() then sbq.SpeciesScript:queueAction("lockDownClear") end
	sbq.addRPC(occupant:sendEntityMessage("sbqDumpOccupants", locationName, subLocationName, occupant.flags.digestType), sbq.receiveOccupants)
	sbq.settings:setParameterSettings()
	sbq.Occupants.queueHudRefresh = true
	return true
end

function default:eggifyAvailable(name, action, target, ...)
	local occupant = sbq.Occupants.entityId[tostring(target)]
	if not occupant then return false, "missingOccupant" end
	if occupant.flags.egged or (sbq.settings:checkInvalid("eggify", true, "locations", occupant.location) ~= (true)) then return false, "invalidAction" end
	local location = occupant:getLocation()
	if not location.secondaryEffects.eggify then return false, "invalidAction" end
	return true
end
function default:eggify(name, action, target, ...)
	local occupant = sbq.Occupants.entityId[tostring(target)]
	if not occupant then return false, "missingOccupant" end
	if occupant.flags.egged or (sbq.settings:checkInvalid("eggify", true, "locations", occupant.location) ~= (true)) then return false, "invalidAction" end
	local location = occupant:getLocation()
	if not location.secondaryEffects.eggify then return false, "invalidAction" end

	if not occupant.locationSettings.eggify then
		occupant.locationSettings.eggify = true
		occupant:refreshLocation()
		return true
	elseif (not world.entity(target):statPositive("sbqEggify")) or
		((occupant:getPublicProperty("sbqEggifyProgress") or 0) < 1) then
		return true
	end
	occupant.locationSettings.eggify = false
	occupant.flags.egged = true
	occupant:sendEntityMessage("applyStatusEffect", action.eggStatus or location.eggStatus or sbq.voreConfig.eggStatus or "sbqEgg")
	occupant:refreshLocation()
end

function default:lockDown(name, action, target, ...)
	if sbq.Occupants.checkActiveOccupants() and sbq.settings.read.actionDialogue and dialogueProcessor and dialogueProcessor.getDialogue(".noPromptAction." .. name, target) then
		dialogueProcessor.sendPlayerDialogueBox(false)
		dialogueProcessor.speakDialogue()
	end
	status.setPersistentEffects("sbqLockDown", {
		"sbqLockDown",
		{ stat = "sbqLockDown", amount = 1 },
		{ stat = "energyRegenPercentageRate", effectiveMultiplier = 0}
	})
end
function default:lockDownClear(name, action, target)
	if sbq.Occupants.checkActiveOccupants() and sbq.settings.read.actionDialogue and dialogueProcessor and dialogueProcessor.getDialogue(".noPromptAction." .. name, target) then
		dialogueProcessor.sendPlayerDialogueBox(false)
		dialogueProcessor.speakDialogue()
	end
	status.clearPersistentEffects("sbqLockDown")
end

function default:releaseOccupantAvailable(name, action, target)
	if sbq.Occupants.list[1] then return true end
	return false, "invalidAction"
end

function default:releaseOccupant(name, action, target)
	local occupant = sbq.Occupants.list[1]
	if not occupant then return false, "invalidAction" end
	if occupant.flags.digested or occupant.flags.infused then
		return sbq.SpeciesScript:queueAction("reform", occupant.entityId)
	end
	return sbq.SpeciesScript:tryAction("letout", occupant.entityId)
end
