
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

function Default:settingAnimations(hideSlots)
	hideSlots = hideSlots or {}
	local legs = sbq.getItemSlot("legsCosmetic") or sbq.getItemSlot("legs")
	if (not hideSlots.legs) and legs and (not root.itemConfig(legs).config.showVoreAnims) and (sbq.voreConfig.legsVoreWhitelist and not sbq.voreConfig.legsVoreWhitelist[legs.name]) then
		self:doAnimations(sbq.voreConfig.legsHide)
	else
		self:doAnimations((sbq.settings.cock and sbq.voreConfig.cockShow) or sbq.voreConfig.cockHide)
		self:doAnimations((sbq.settings.pussy and sbq.voreConfig.pussyShow) or sbq.voreConfig.pussyHide)
		self:doAnimations((sbq.settings.balls and (not sbq.settings.ballsInternal) and sbq.voreConfig.ballsShow) or sbq.voreConfig.ballsHide)
	end
	local chest = sbq.getItemSlot("chestCosmetic") or sbq.getItemSlot("chest")
	if (not hideSlots.chest) and chest and (not root.itemConfig(chest).config.showVoreAnims) and (sbq.voreConfig.chestVoreWhitelist and not sbq.voreConfig.chestVoreWhitelist[chest.name]) then
		self:doAnimations(sbq.voreConfig.chestHide)
	else
		self:doAnimations((sbq.settings.breasts and sbq.voreConfig.breastsShow) or sbq.voreConfig.breastsHide)
	end
end

function Default:getHideSlotAnims(hideSlots)
	local hide, show = {}, {}
	for k, v in pairs(hideSlots) do
		if v then
			local item = sbq.getItemSlot(k.."Cosmetic") or sbq.getItemSlot(k)
			if item and not ((sbq.voreConfig[k.."VoreWhitelist"] or {})[item.name])then
				hide[k.."CosmeticHiddenState"] = "none"
				show[k.."CosmeticHiddenState"] = "ignore"
			end
		end
	end
	return hide, show
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
	if not location then return false, "invalidLocation" end
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
	if not location.sendDeeperAction then return false, "invalidAction" end
	for i, occupant in ipairs(location.occupancy.list) do
		if not (occupant.flags.infused or occupant.flags.digested) then
			return SpeciesScript:tryAction(location.sendDeeperAction.action, occupant.entityId, table.unpack(location.sendDeeperAction.args or {}))
		end
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
		if throughput or action.throughput then
			if (size) >= ( throughput or action.throughput * sbq.scale()) then return false, "tooBig" end
		end
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
	if not target then return true end

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
	if sbq.statPositive("sbqIsPrey") or sbq.statPositive("sbqEntrapped") then return false, "nested" end
	if target == sbq.loungingIn() then return false, "invalidAction" end
	local loungeAnchor = world.entityCurrentLounge(target)
	if loungeAnchor and (loungeAnchor.entityId ~= entity.id()) and (not loungeAnchor.dismountable) then return false, "invalidAction" end
	local size = sbq.getEntitySize(target)
	if throughput or action.throughput then
		if (size) >= ( throughput or action.throughput * sbq.scale()) then return false, "tooBig" end
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
	self:trySendDeeper(name, action, nil, nil, locationName, subLocationName)

	local space, subLocation = location:hasSpace(size)
	if space or (action.flags and action.flags.infusing) then
		if Occupants.addOccupant(target, size, locationName or action.location, subLocation, action.flags) then
			world.sendEntityMessage(entity.id(), "sbqControllerRotation", false) -- just to clear hand rotation if one ate from grab
			SpeciesScript.lockActions = true
			local hide, show = SpeciesScript:getHideSlotAnims(action.hideSlots or {})
			SpeciesScript:doAnimations(hide)
			SpeciesScript:settingAnimations(action.hideSlots)
			return true, function()
				sbq.forceTimer(name.."ShowCosmeticAnims", 5, function ()
					SpeciesScript:doAnimations(show)
					SpeciesScript:settingAnimations()
				end)
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
	if sbq.statPositive("sbqIsPrey") or sbq.statPositive("sbqEntrapped") then return false, "nested" end
	local occupant = Occupants.entityId[tostring(target)]
	if not occupant then return false end
	if throughput or action.throughput then
		if (occupant.size * occupant.sizeMultiplier) >= ((throughput or action.throughput) * sbq.scale()) then return false end
	end
	if occupant.flags.digested or occupant.flags.infused then return false end
	occupant.flags.releasing = true
	occupant.sizeMultiplier = 0 -- so belly expand anims start going down right away
	occupant:getLocation().occupancy.sizeDirty = true
	SpeciesScript.lockActions = true
	local hide, show = SpeciesScript:getHideSlotAnims(action.hideSlots or {})
	SpeciesScript:doAnimations(hide)
	SpeciesScript:settingAnimations(action.hideSlots)
	sbq.forceTimer("huntTargetSwitchCooldown", 30)
	return true, function()
		sbq.forceTimer(name.."ShowCosmeticAnims", 5, function ()
			SpeciesScript:doAnimations(show)
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

function default:digested(name, action, target, item, digestType, drop, ...)
	local occupant = Occupants.entityId[tostring(target)]
	if not occupant then return false end
	local location = occupant:getLocation()
	occupant.flags.digested = true
	occupant.flags.digestedLocation = occupant.location
	occupant.flags.digestType = digestType
	occupant.sizeMultiplier = action.sizeMultiplier or location.digestedSizeMultiplier or 1
	occupant.size = action.size or location.digestedSize or 0
	location:markSizeDirty()
	return true, function()
		local position = occupant:position()
		occupant:refreshLocation()
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
			item.name = "sbqNPCEssenceJar"
			table.insert(storage.sbqSettings.recentlyDigested, 1, item)
			while #storage.sbqSettings.recentlyDigested > sbq.config.recentlyDigestedCount do
				table.remove(storage.sbqSettings.recentlyDigested, #storage.sbqSettings.recentlyDigested)
			end
		end
	end
end

function default:fatalAvailable(name, action, target, ...)
	local occupant = Occupants.entityId[tostring(target)]
	if not occupant then return false end
	if not occupant.flags.digested then return false, "invalidAction" end
	if not occupant.flags.digestType then return false, "invalidAction" end
	if occupant:statPositive("sbq_"..(occupant.flags.digestType).."FatalImmune") then return false, "invalidAction" end
	return true
end
function default:fatal(name, action, target, ...)
	local occupant = Occupants.entityId[tostring(target)]
	if not occupant then return false end
	if not occupant.flags.digested then return false, "invalidAction" end
	if not occupant.flags.digestType then return false, "invalidAction" end
	if occupant:statPositive("sbq_"..(occupant.flags.digestType).."FatalImmune") then return false, "invalidAction" end
	occupant:modifyResourcePercentage("health", -2)
	return true
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
		occupant.locationSettings.reformDigested = true
		occupant:refreshLocation()
		return true
	else
		return SpeciesScript:tryAction("reformed", target)
	end
end
function default:reformed(name, action, target,...)
	local occupant = Occupants.entityId[tostring(target)]
	if not occupant then return false end
	local location = occupant:getLocation()
	if occupant.flags.infused then
		location.infusedEntity = nil
		sbq.settings.infuseSlots[occupant.flags.infuseType].item = nil
		sbq.infuseOverrideSettings[occupant.flags.infuseType] = nil
		SpeciesScript:refreshInfusion(occupant.flags.infuseType)
	end
	occupant.flags.infuseType = nil
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
	if not (occupant.locationSettings.reformDigested or occupant.flags.infused) then return false, "invalidAction" end
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

function default:transformAvailable(name, action, target, ...)
	local occupant = Occupants.entityId[tostring(target)]
	if not occupant then return false end
	local location = occupant:getLocation()
	local transformResult = action.transformResult or location.transformResult or sbq.voreConfig.transformResult or { species = humanoid.species() }
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
	if not occupant then return false end
	local location = occupant:getLocation()
	local transformResult = action.transformResult or location.transformResult or sbq.voreConfig.transformResult or { species = humanoid.species() }
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
	if not occupant then return false end
	local location = occupant:getLocation()
	local transformResult = action.transformResult or location.transformResult or sbq.voreConfig.transformResult or { species = humanoid.species() }
	local transformDuration = action.transformDuration or location.transformDuration or sbq.voreConfig.transformDuration or 10
	if not transformResult then return false, "invalidAction" end
	local checkSettings = {
		speciesTF = transformResult.species and true,
		genderTF = transformResult.gender and true
	}
	if not sbq.tableMatches(checkSettings, sbq.getPublicProperty(target, "sbqPublicSettings")) then return false, "targetSettingsMismatch" end

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
	occupant.flags.infused = true
	occupant.flags.infusing = false
	occupant.flags.infuseType = infuseType
	occupant.locationSettings[infuseType.."Digested"] = false
	occupant.locationSettings[infuseType] = false
	sbq.addRPC(occupant:sendEntityMessage("sbqGetCard"), function(card)
		sbq.settings.infuseSlots[infuseType].item = card
		sbq.infuseOverrideSettings[infuseType] = {
			infuseSlots = { [infuseType] = { item = card}}
		}
		SpeciesScript:refreshInfusion(infuseType)
		occupant:refreshLocation(action.location)
		location:markSizeDirty()
	end)
	return true
end


function default:eggify(name, action, target, ...)
	local occupant = Occupants.entityId[tostring(target)]
	if not occupant then return false end
	if not occupant.locationSettings.eggify then
		occupant.locationSettings.eggify = true
		occupant:refreshLocation()
		return true
	elseif (not world.entityStatPositive(target, "sbqEggify")) or
		((occupant:getPublicProperty("sbqEggifyProgress") or 0) < 1) then
		return true
	end
	local location = occupant:getLocation()
	occupant.locationSettings.eggify = false
	occupant:sendEntityMessage("applyStatusEffect", action.eggStatus or location.eggStatus or sbq.voreConfig.eggStatus or "sbqEgg" )
end

function default:lockDown()
	if sbq.statPositive("sbqLockDown") then
		sbq.clearStatModifiers("sbqLockDown")
	else
		sbq.setStatModifiers("sbqLockDown", {
			{ stat = "sbqLockDown", amount = 1 },
			{ stat = "energyRegenPercentageRate", baseMultiplier = 0}
		})
	end
end
