
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

function Default:settingAnimations()
	local lust = 0
	if sbq.isResource("sbqLust") then
		lust = sbq.resourcePercentage("sbqLust")
	end
	local legs = sbq.getItemSlot("legsCosmetic") or sbq.getItemSlot("legs")
	if (not (sbq.statPositive("legsNude") or sbq.statPositive("nude"))) and legs and (not root.itemConfig(legs).config.showVoreAnims) and (sbq.voreConfig.legsVoreWhitelist and not sbq.voreConfig.legsVoreWhitelist[legs.name]) then
		self:doAnimations(sbq.voreConfig.legsHide)
		for _, v in ipairs(sbq.voreConfig.cockParticleEmitters or {}) do
			animator.setParticleEmitterActive(v, false)
		end
		for _, v in ipairs(sbq.voreConfig.pussyParticleEmitters or {}) do
			animator.setParticleEmitterActive(v, false)
		end
	else
		self:doAnimations((sbq.settings.cock and sbq.voreConfig.cockShow) or sbq.voreConfig.cockHide)
		self:doAnimations((sbq.settings.pussy and sbq.voreConfig.pussyShow) or sbq.voreConfig.pussyHide)
		self:doAnimations((sbq.settings.balls and (not sbq.settings.ballsInternal) and sbq.voreConfig.ballsShow) or sbq.voreConfig.ballsHide)

		if (sbq.settings.cockLeakiness > (1 - lust)) and sbq.settings.cock and not sbq.checkStarpounds("legs") then
			local leakiness = ((sbq.settings.cockLeakiness^2 * lust)^2)*10*math.max(0.25, ((Occupants.locations.cock or {}).count or 0) + ((Occupants.locations.balls or {}).count or 0))
			for _, v in ipairs(sbq.voreConfig.cockParticleEmitters or {}) do
				animator.setParticleEmitterActive(v, true)
				animator.setParticleEmitterEmissionRate(v, leakiness)
			end
		else
			for _, v in ipairs(sbq.voreConfig.cockParticleEmitters or {}) do
				animator.setParticleEmitterActive(v, false)
			end
		end

		if (sbq.settings.pussyLeakiness > (1 - lust)) and sbq.settings.pussy and not sbq.checkStarpounds("legs") then
			local leakiness = ((sbq.settings.pussyLeakiness^2 * lust)^2)*10*math.max(0.25, ((Occupants.locations.womb or {}).count or 0) + ((Occupants.locations.pussy or {}).count or 0))
			for _, v in ipairs(sbq.voreConfig.pussyParticleEmitters or {}) do
				animator.setParticleEmitterActive(v, true)
				animator.setParticleEmitterEmissionRate(v, leakiness)
			end
		else
			for _, v in ipairs(sbq.voreConfig.pussyParticleEmitters or {}) do
				animator.setParticleEmitterActive(v, false)
			end
		end
	end
	local chest = sbq.getItemSlot("chestCosmetic") or sbq.getItemSlot("chest")
	if (not (sbq.statPositive("chestNude") or sbq.statPositive("nude"))) and chest and (not root.itemConfig(chest).config.showVoreAnims) and (sbq.voreConfig.chestVoreWhitelist and not sbq.voreConfig.chestVoreWhitelist[chest.name]) then
		self:doAnimations(sbq.voreConfig.chestHide)
		for _, v in ipairs(sbq.voreConfig.breastsParticleEmitters or {}) do
			animator.setParticleEmitterActive(v, false)
		end
	else
		self:doAnimations((sbq.settings.breasts and sbq.voreConfig.breastsShow) or sbq.voreConfig.breastsHide)
		if (sbq.settings.breastsLeakiness > (1 - lust)) and sbq.settings.breasts and not sbq.checkStarpounds("chest") then
			local leakiness = ((sbq.settings.breastsLeakiness^2 * lust)^2)*10*math.max(0.25, ((Occupants.locations.breasts or {}).count or 0))
			for _, v in ipairs(sbq.voreConfig.breastsParticleEmitters or {}) do
				animator.setParticleEmitterActive(v, true)
				animator.setParticleEmitterEmissionRate(v, leakiness)
			end
		else
			for _, v in ipairs(sbq.voreConfig.breastsParticleEmitters or {}) do
				animator.setParticleEmitterActive(v, false)
			end
		end
	end
	self:doAnimations((sbq.settings.breasts and sbq.voreConfig.braHide) or sbq.voreConfig.braShow)
	self:doAnimations(((sbq.settings.cock or sbq.settings.pussy or sbq.settings.balls) and sbq.voreConfig.underwearHide) or sbq.voreConfig.underwearShow)

end

function Default:hideSlots(hideSlots)
	local modifiers = {}
	for k, v in pairs(hideSlots) do
		if v then table.insert(modifiers, {stat = k.."Nude", amount = 1})end
	end
	sbq.setStatModifiers("sbqHideSlots", modifiers)
end
function Default:showSlots()
	sbq.clearStatModifiers("sbqHideSlots")
end
function Default:refreshStripping()
	if not sbq.isResource("sbqLust") then return end
	local modifiers = {}
	for _, k in ipairs({"head","chest","legs","back"}) do
		if sbq.resourcePercentage("sbqLust") > sbq.settings[k.."Strip"] then
			table.insert(modifiers, {stat = k.."Nude", amount = 1})
		end
	end
	sbq.setStatModifiers("sbqStripping", modifiers)
	SpeciesScript:settingAnimations()
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
		if (target and action.untilFirstSuccess) and not SpeciesScript:actionAvailable(actionData[1], nil, table.unpack(actionData[2] or action.args or {}) ) then
		else
			results = { SpeciesScript:tryAction(actionData[1], target, table.unpack(actionData[2] or action.args or {})) }
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
		if (target and action.untilFirstSuccess) and not SpeciesScript:actionAvailable(actionData[1], nil, table.unpack(actionData[2] or action.args or {}) ) then
		else
			results = {SpeciesScript:actionAvailable(actionData[1], target, table.unpack(actionData[2] or action.args or {}))}
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
	occupant = Occupants.entityId[tostring(target)]
	if not occupant then return false, "missingOccupant" end
	local location = SpeciesScript:getLocation(locationName or action.location, subLocationName or action.subLocation)
	if not location then return false, "invalidLocation" end
	local size = (occupant.size * occupant.sizeMultiplier)
	throughput = throughput or action.throughput
	if throughput and not location.settings.hammerspace then
		if size > (throughput * sbq.scale()) then return false, "tooBig" end
	end
	local space, subLocation = location:hasSpace(size)
	if space then
        occupant:refreshLocation(locationName or action.location, subLocation)
		location:refreshStruggleDirection()
		return true, function ()
			occupant = Occupants.entityId[tostring(target)]
			if occupant then
				occupant:refreshLocation()
				location:refreshStruggleDirection()
			end
		end
	end
	return false, "noSpace"
end
function default:moveToLocationAvailable(name, action, target, locationName, subLocationName, throughput, ...)
	occupant = Occupants.entityId[tostring(target)]
	if not occupant then return false, "missingOccupant" end
	local location = SpeciesScript:getLocation(locationName or action.location, subLocationName or action.subLocation)
	if not location then return false, "invalidLocation" end
	local size = (occupant.size * occupant.sizeMultiplier)
	throughput = throughput or action.throughput
	if throughput and not location.settings.hammerspace then
		if size > (throughput * sbq.scale()) then return false, "tooBig" end
	end
	local space, subLocation = location:hasSpace(size)
	if space then
		return true
	end
	return false, "noSpace"
end

function default:trySendDeeperAvailable(name, action, target, failureReason, size, ...)
	if target then
		local occupant = Occupants.entityId[tostring(target)]
		if not occupant then return false, "missingOccupant" end
		local location = occupant:getLocation()
		if not location then return false, "invalidLocation" end
		if not location.sendDeeperAction then return false, "invalidAction" end
		if not occupant:active() then return false, "invalidAction" end
        return SpeciesScript:actionAvailable(location.sendDeeperAction.action, target, table.unpack(location.sendDeeperAction.args or {}))
    else
		local location = SpeciesScript:getLocation(action.location, action.subLocation)
		if not location then return false, "invalidLocation" end
        if not location.sendDeeperAction then return false, "invalidAction" end
        local spaceNeeded = (size * location.settings.multiplyFill / sbq.scale()) - location:getRemainingSpace()
        local success, newFailureReason
		for _, occupant in ipairs(location.occupancy.list) do
			success, newFailureReason = self:trySendDeeperAvailable(name, action, occupant.entityId)
			if success then
				local occupantSize = occupant.size * occupant.sizeMultiplier * location.settings.multiplyFill / sbq.scale()
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
        local occupant = Occupants.entityId[tostring(target)]
		if not occupant then return false, "missingOccupant" end
		local location = occupant:getLocation()
		if not location then return false, "invalidLocation" end
		if not location.sendDeeperAction then return false, "invalidAction" end
		if not occupant:active() then return false, "invalidAction" end
		return SpeciesScript:tryAction(location.sendDeeperAction.action, occupant.entityId, table.unpack(location.sendDeeperAction.args or {}))
    else
		local location = SpeciesScript:getLocation(action.location, action.subLocation)
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
	if sbq.statPositive("sbqIsPrey") or sbq.statPositive("sbqEntrapped") then return false, "nested" end
	local size
	if target then
		if (target == sbq.loungingIn()) then return false, "invalidAction" end
		local loungeAnchor = world.entityCurrentLounge(target)
		if loungeAnchor and (loungeAnchor.entityId ~= entity.id()) and (not loungeAnchor.dismountable) then return false, "invalidAction" end
		size = sbq.getEntitySize(target)
	end
	local location = SpeciesScript:getLocation(locationName or action.location, subLocationName or action.subLocation)
	if not location then return false, "invalidLocation" end
	if location.activeSettings then
		if not sbq.tableMatches(location.activeSettings, sbq.settings, true) then
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
		if size > (throughput * sbq.scale()) then return false, "tooBig" end
	end

	local space, subLocation = location:hasSpace(size)

	if not space and location.sendDeeperAction then
        if self:trySendDeeperAvailable(name, action, nil, "noSpace", size) then
			space = size
		end
	end

	if space or (action.flags and action.flags.infusing) then
		if (#Occupants.list + 1) <= sbq.config.seatCount then
			return true
		else
			return false, "noSlots"
		end
	else
		return false, "noSpace"
	end
end

function default:tryVore(name, action, target, ...)
	if sbq.statPositive("sbqIsPrey") or sbq.statPositive("sbqEntrapped") then return false, "nested" end
	if target == sbq.loungingIn() then return false, "invalidAction" end
	local loungeAnchor = world.entityCurrentLounge(target)
	if loungeAnchor and (loungeAnchor.entityId ~= entity.id()) and (not loungeAnchor.dismountable) then return false, "invalidAction" end
	local size = sbq.getEntitySize(target)
	local location = SpeciesScript:getLocation(action.location, action.subLocation)
	if not location then return false, "invalidLocation" end
	if location.activeSettings then
		if not sbq.tableMatches(location.activeSettings, sbq.settings, true) then
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
		if size > (throughput * sbq.scale()) then return false, "tooBig" end
	end


	local space, subLocation = location:hasSpace(size)

	if not space and location.sendDeeperAction then
        self:trySendDeeper(name, action, nil, "noSpace", size)
		space, subLocation = location:hasSpace(size)
	end

	if space or (action.flags and action.flags.infusing) then
		location.occupancy.lockSize = action.lockSize or location.occupancy.lockSize
		if Occupants.newOccupant(target, size, action.location, subLocation, action.flags) then
			world.sendEntityMessage(entity.id(), "sbqControllerRotation", false) -- just to clear hand rotation if one ate from grab
			SpeciesScript.lockActions = true
			SpeciesScript:hideSlots(action.hideSlots or {})
			SpeciesScript:settingAnimations()
			return true, function()
				sbq.forceTimer(name.."ShowCosmeticAnims", 5, function ()
					SpeciesScript:showSlots()
					SpeciesScript:settingAnimations()
				end)
				local occupant = Occupants.entityId[tostring(target)]
				if occupant then
					occupant.flags.newOccupant = false
					occupant:refreshLocation()
					if action.lockSize then
						location.occupancy.lockSize = false
						location:markSizeDirty()
					end
				end
				SpeciesScript.lockActions = false
			end
		else
			if action.lockSize then
				location.occupancy.lockSize = false
			end
			return false, "noSlots"
		end
	else
		if action.lockSize then
			location.occupancy.lockSize = false
		end
		return false, "noSpace"
	end
end
function default:tryLetout(name, action, target, throughput, ...)
	if sbq.statPositive("sbqIsPrey") or sbq.statPositive("sbqEntrapped") then return false, "nested" end
	local occupant = Occupants.entityId[tostring(target)]
	if not occupant then return false, "missingOccupant" end
	throughput = throughput or action.throughput
	if throughput and not occupant.locationSettings.hammerspace then
		if (occupant.size * occupant.sizeMultiplier) > (throughput * sbq.scale()) then return false, "tooBig" end
	end
	if occupant.flags.digested or occupant.flags.infused or occupant.flags.digesting then return false, "invalidAction" end
	local location = occupant:getLocation()
	if not location then return false, "invalidAction" end
	location.occupancy.lockSize = action.lockSize or location.occupancy.lockSize
	if (not action.lockSize) or (action.location and (location.key ~= action.location)) then
		location:markSizeDirty()
	end
	occupant.flags.releasing = true
	SpeciesScript.lockActions = true
	SpeciesScript:hideSlots(action.hideSlots or {})
	SpeciesScript:settingAnimations()
	sbq.forceTimer("huntTargetSwitchCooldown", 30)
	return true, function()
		if action.lockSize and ((not action.location) or (action.location == location.key)) then
			location.occupancy.lockSize = false
			location:markSizeDirty()
		end
		sbq.forceTimer(name.."ShowCosmeticAnims", 5, function ()
			SpeciesScript:showSlots()
			SpeciesScript:settingAnimations()
		end)
		sbq.forceTimer("huntTargetSwitchCooldown", 30)
		local occupant = Occupants.entityId[tostring(target)]
		SpeciesScript.lockActions = false
		if occupant then occupant:remove() end
	end
end
local function letout(funcName, action, target, preferredAction, ...)
	if sbq.statPositive("sbqIsPrey") or sbq.statPositive("sbqEntrapped") then return false, "nested" end
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
		for i = #Occupants.list, 1, -1 do
			local occupant = Occupants.list[i]
			if SpeciesScript[funcName](SpeciesScript, "letout", occupant.entityId) then
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
	if not location then return false, "invalidLocation" end
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
		if not location then return false, "invalidLocation" end
		occupant = location.occupancy.list[1]
	end
	if occupant then
		animator.playSound("release")
		occupant:remove()
		world.sendEntityMessage(entity.id(), "sbqControllerRotation", false)
		return true
	else
		return false, "missingOccupant"
	end
end

function default:turboDigestAvailable(name, action, target, ...)
	local occupant = Occupants.entityId[tostring(target)]
	if not occupant then return false, "missingOccupant" end
	local location = occupant:getLocation()
	local mainEffect = occupant.locationSettings.mainEffect
	if (not location.mainEffect) or ((not location.mainEffect.digest) and (not location.mainEffect.softDigest)) then return false, "invalidAction" end
	if not ((mainEffect == "digest") or (mainEffect == "softDigest")) then return false, "invalidAction" end
	return true
end
function default:turboDigest(name, action, target, ...)
	if not self:turboDigestAvailable(name, action, target, ...) then return false, "invalidAction" end
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
	if not self:turboHealAvailable(name, action, target, ...) then return false, "invalidAction" end
	local occupant = Occupants.entityId[tostring(target)]
	occupant:sendEntityMessage("sbqTurboHeal", sbq.resource("energy"))
	sbq.overConsumeResource("energy", sbq.resourceMax("energy"))
end

function default:digested(name, action, target, item, digestType, drop, ...)
	local occupant = Occupants.entityId[tostring(target)]
	local position = entity.position()
	local location
	local delay = 0
	if occupant then
		location = occupant:getLocation()
		position = occupant:position()
		occupant.flags.digesting = true
		occupant.flags.digestedLocation = occupant.location
		occupant.flags.digestType = digestType
		occupant.sizeMultiplier = action.sizeMultiplier or location.digestedSizeMultiplier or 1
		occupant.size = action.size or location.digestedSize or 0
		occupant:refreshLocation()
		sbq.addRPC(occupant:sendEntityMessage("sbqDumpOccupants", occupant.location, occupant.subLocation, digestType), sbq.recieveOccupants)
	end
	if location then
		location:markSizeDirty()
		local sizeChangeAnims = location.occupancy.queuedSizeChangeAnims or location.sizeChangeAnims
		if sizeChangeAnims then
			delay = SpeciesScript:checkAnimations(false, sizeChangeAnims, {})
		end
		if location.digestedAnims then
			delay = math.max(delay, SpeciesScript:checkAnimations(false, location.digestedAnims, {}, target))
		end
	end
	if not Occupants.checkActiveOccupants() then SpeciesScript:queueAction("lockDownClear") end
	sbq.timer(target .. "Digesting", delay, function()
		local occupant = Occupants.entityId[tostring(target)]
		if occupant then
			occupant.flags.digesting = false
			occupant.flags.digested = true
			occupant:refreshLocation()
		end
		if item then
			item.parameters.predName = sbq.entityName(entity.id())
			item.parameters.predUuid = entity.uniqueId()
			item.parameters.predPronouns = sbq.getPublicProperty(entity.id(), "sbqPronouns")
			if humanoid then
				item.parameters.predIdentity = humanoid.getIdentity()
			end
			if item.name and sbq.settings[digestType.."Drops"] and drop then
				world.spawnItem(item, position)
			end
			-- we can drop condoms and milk for monsters, but if we don't have NPC data theres no reason to preserve it
			if not item.parameters.npcArgs then return end
			item.name = "sbqNPCEssenceJar"
			if not storage.sbqSettings.recentlyDigested[1] then
				storage.sbqSettings.recentlyDigested = _ENV.jarray()
			end
			table.insert(storage.sbqSettings.recentlyDigested, 1, item)
			while #storage.sbqSettings.recentlyDigested > sbq.config.recentlyDigestedCount do
				table.remove(storage.sbqSettings.recentlyDigested, #storage.sbqSettings.recentlyDigested)
			end
		end
	end)
	return true
end

function default:fatalAvailable(name, action, target, ...)
	local occupant = Occupants.entityId[tostring(target)]
	if not occupant then return false, "missingOccupant" end
	if not occupant.flags.digested then return false, "invalidAction" end
	if not occupant.flags.digestType then return false, "invalidAction" end
	if occupant:statPositive("sbq_" .. (occupant.flags.digestType) .. "FatalImmune") then return false, "invalidAction" end
	if sbq.checkInvalidSetting("digest", "mainEffect", "locations", occupant.location) ~= nil then return false, "invalidAction" end
	return true
end
function default:fatal(name, action, target, ...)
	local occupant = Occupants.entityId[tostring(target)]
	if not occupant then return false, "missingOccupant" end
	if not occupant.flags.digested then return false, "invalidAction" end
	if not occupant.flags.digestType then return false, "invalidAction" end
	if occupant:statPositive("sbq_" .. (occupant.flags.digestType) .. "FatalImmune") then return false, "invalidAction" end
	if sbq.checkInvalidSetting("digest", "mainEffect", "locations", occupant.location) ~= nil then return false, "invalidAction" end
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
	local occupant = Occupants.entityId[tostring(target)]
	if not occupant then return false, "invalidAction" end
	if occupant.locationSettings.mainEffect == (action.mainEffect or name) then return false, "invalidAction" end
	if sbq.checkInvalidSetting(action.mainEffect or name, "mainEffect", "locations", occupant.location) ~= nil then return false, "invalidAction" end
	local location = occupant:getLocation()
	if location.mainEffect[action.mainEffect or name] then
		return true
	end
	return false, "invalidAction"
end
function default:setMainEffect(name, action, target)
	local occupant = Occupants.entityId[tostring(target)]
	if not occupant then return false, "missingOccupant" end
	if sbq.checkInvalidSetting(action.mainEffect or name, "mainEffect", "locations", occupant.location) ~= nil then return false, "invalidAction" end
	occupant.locationSettings.mainEffect = action.mainEffect or name
	occupant:refreshLocation()
end

function default:reform(name, action, target,...)
	local occupant = Occupants.entityId[tostring(target)]
	if not occupant then return false, "missingOccupant" end
	if occupant:resourcePercentage("health") < 1 then
		occupant.locationSettings.reformDigested = true
		occupant:refreshLocation()
		return true
	else
		return SpeciesScript:tryAction("reformed", target)
	end
end
function default:reformed(name, action, target,...)
	local occupant = Occupants.entityId[tostring(target)]
	if not occupant then return false, "missingOccupant" end
	local location = occupant:getLocation()
	if occupant.flags.infused then
		location.infusedEntity = nil
		sbq.settings.infuseSlots[occupant.flags.infuseType].item = nil
		sbq.infuseOverrideSettings[occupant.flags.infuseType] = nil
		SpeciesScript:refreshInfusion(occupant.flags.infuseType)
	end
	occupant.flags.infuseType = nil
	occupant.flags.infused = false
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
	local occupant = Occupants.entityId[tostring(target)]
	if not occupant then return false, "missingOccupant" end
	if not (occupant.locationSettings.reformDigested or occupant.flags.infused) then return false, "invalidAction" end
	return true
end
function default:turboReform(name, action, target, ...)
	if not self:turboReformAvailable(name, action, target, ...) then return false, "invalidAction" end
	local occupant = Occupants.entityId[tostring(target)]
	occupant:sendEntityMessage("sbqTurboHeal", sbq.resource("energy"))
	sbq.overConsumeResource("energy", sbq.resourceMax("energy"))
end


function default:chooseLocation(name, action, target, predSelect, ...)
	local locations = {}
	local occupant = Occupants.entityId[tostring(target)]
	if not occupant then return false, "missingOccupant" end
	for _, locationName in ipairs(action.locationOrder or sbq.voreConfig.locationOrder or root.assetJson("/sbqGui.config:locationOrder")) do
		local location = SpeciesScript:getLocation(locationName)
		if location and sbq.tableMatches(location.activeSettings, sbq.settings, true) then
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
	local occupant = Occupants.entityId[tostring(target)]
	if not occupant then return false, "missingOccupant" end
	local location = occupant:getLocation()
	local transformResult = sb.jsonMerge({species = humanoid.species()}, sbq.voreConfig.transformResult or {}, action.transformResult or {}, location.transformResult or {})
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
	local occupant = Occupants.entityId[tostring(target)]
	if not occupant then return false, "missingOccupant" end
	local location = occupant:getLocation()
	local transformResult = sb.jsonMerge({species = humanoid.species()}, sbq.voreConfig.transformResult or {}, action.transformResult or {}, location.transformResult or {})
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
	local occupant = Occupants.entityId[tostring(target)]
	if not occupant then return false, "missingOccupant" end
	local location = occupant:getLocation()
	local transformResult = sb.jsonMerge({species = humanoid.species()}, sbq.voreConfig.transformResult or {}, action.transformResult or {}, location.transformResult or {})
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
	local location = SpeciesScript:getLocation(action.location)
	if not location then return false, "invalidLocation" end
	if location.infusedEntity and Occupants.entityId[tostring(location.infusedEntity)]then return false, "alreadyInfused" end

	local occupant = Occupants.entityId[tostring(target)]
	if occupant then
		return true
	else
		return SpeciesScript:actionAvailable(action.voreAction, target)
	end
end
function default:tryInfuse(name, action, target, ...)
	local location = SpeciesScript:getLocation(action.location)
	local infuseType = action.infuseType or location.infuseType or name
	if location.infusedEntity and Occupants.entityId[tostring(location.infusedEntity)] then return false, "alreadyInfused" end
	local occupant = Occupants.entityId[tostring(target)]
	if occupant then
		occupant.locationSettings[infuseType.."Digested"] = true
		occupant.locationSettings[infuseType] = true
		occupant:refreshLocation()
		return true
	else
		local res = { SpeciesScript:tryAction(action.voreAction, target) }
		if res[1] then
			SpeciesScript:queueAction(action.finishAction or name, target)
		end
		return table.unpack(res)
	end
end
function default:infused(name, action, target)
	local location = SpeciesScript:getLocation(action.location)
	local infuseType = action.infuseType or location.infuseType or name
	local occupant = Occupants.entityId[tostring(target)]
	if not occupant then return false, "missingOccupant" end
	if location.infusedEntity and Occupants.entityId[tostring(location.infusedEntity)] then
		occupant.locationSettings[infuseType.."Digested"] = false
		occupant.locationSettings[infuseType] = false
		occupant:refreshLocation()
		return false, "alreadyInfused"
	end
	location.infusedEntity = target
	occupant.flags.digested = false
	occupant.flags.digesting = false
	occupant.flags.infused = true
	occupant.flags.infusing = false
	occupant.flags.infuseType = infuseType
	occupant.locationSettings[infuseType.."Digested"] = false
	occupant.locationSettings[infuseType] = false
	local locationName = occupant.location
	local subLocationName = occupant.subLocation
	if not Occupants.checkActiveOccupants() then SpeciesScript:queueAction("lockDownClear") end
	sbq.addRPC(occupant:sendEntityMessage("sbqGetCard"), function(card)
		sbq.settings.infuseSlots[infuseType].item = card
		sbq.infuseOverrideSettings[infuseType] = {
			infuseSlots = { [infuseType] = { item = card}}
		}
		SpeciesScript:refreshInfusion(infuseType)
		occupant:refreshLocation(action.location)
		location:markSizeDirty()
		sbq.addRPC(occupant:sendEntityMessage("sbqDumpOccupants", locationName, subLocationName, occupant.flags.digestType), sbq.recieveOccupants)
	end)
	return true
end

function default:eggifyAvailable(name, action, target, ...)
	local occupant = Occupants.entityId[tostring(target)]
	if not occupant then return false, "missingOccupant" end
	if occupant.flags.egged or (sbq.checkInvalidSetting("true", "eggify", "locations", occupant.location) ~= nil) then return false, "invalidAction" end
	local location = occupant:getLocation()
	if not location.secondaryEffects.eggify then return false, "invalidAction" end
	return true
end
function default:eggify(name, action, target, ...)
	local occupant = Occupants.entityId[tostring(target)]
	if not occupant then return false, "missingOccupant" end
	if occupant.flags.egged or (sbq.checkInvalidSetting("true", "eggify", "locations", occupant.location) ~= nil) then return false, "invalidAction" end
	local location = occupant:getLocation()
	if not location.secondaryEffects.eggify then return false, "invalidAction" end

	if not occupant.locationSettings.eggify then
		occupant.locationSettings.eggify = true
		occupant:refreshLocation()
		return true
	elseif (not world.entityStatPositive(target, "sbqEggify")) or
		((occupant:getPublicProperty("sbqEggifyProgress") or 0) < 1) then
		return true
	end
	occupant.locationSettings.eggify = false
	occupant.flags.egged = true
	occupant:sendEntityMessage("applyStatusEffect", action.eggStatus or location.eggStatus or sbq.voreConfig.eggStatus or "sbqEgg")
	occupant:refreshLocation()
end

function default:lockDown(name, action, target, ...)
	if Occupants.checkActiveOccupants() and sbq.settings.actionDialogue and dialogueProcessor and dialogueProcessor.getDialogue(".noPromptAction." .. name, target) then
		dialogueProcessor.sendPlayerDialogueBox(false)
		dialogueProcessor.speakDialogue()
	end
	sbq.setStatModifiers("sbqLockDown", {
		"sbqLockDown",
		{ stat = "sbqLockDown", amount = 1 },
		{ stat = "energyRegenPercentageRate", effectiveMultiplier = 0}
	})
end
function default:lockDownClear(name, action, target)
	if Occupants.checkActiveOccupants() and sbq.settings.actionDialogue and dialogueProcessor and dialogueProcessor.getDialogue(".noPromptAction." .. name, target) then
		dialogueProcessor.sendPlayerDialogueBox(false)
		dialogueProcessor.speakDialogue()
	end
	sbq.clearStatModifiers("sbqLockDown")
end

function default:releaseOccupantAvailable(name, action, target)
	if Occupants.list[1] then return true end
	return false, "invalidAction"
end

function default:releaseOccupant(name, action, target)
	local occupant = Occupants.list[1]
	if not occupant then return false, "invalidAction" end
	if occupant.flags.digested or occupant.flags.infused then
		return SpeciesScript:queueAction("reform", occupant.entityId)
	end
	return SpeciesScript:tryAction("letout", occupant.entityId)
end
