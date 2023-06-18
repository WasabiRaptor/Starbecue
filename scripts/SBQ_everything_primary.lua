local mysteriousTFDuration
require("/scripts/rect.lua")

function sbq.everything_primary()
	message.setHandler("sbqApplyStatusEffects", function(_,_, statlist)
		for statusEffect, data in pairs(statlist) do
			status.setStatusProperty(statusEffect, data.property)
			status.addEphemeralEffect(statusEffect, data.power, data.source)
		end
	end)
	message.setHandler("sbqRemoveStatusEffects", function(_,_, statlist, resetHealth)
		for _, statusEffect in ipairs(statlist) do
			status.removeEphemeralEffect(statusEffect)
		end
		if resetHealth then
			status.resetResource("health")
		end
	end)
	message.setHandler("sbqRemoveStatusEffect", function(_,_, statusEffect)
		status.removeEphemeralEffect(statusEffect)
	end)

	message.setHandler("sbqApplyScaleStatus", function(_,_, scale)
		status.setStatusProperty("sbqScaling", scale)
		status.addEphemeralEffect("sbqScaling")
	end)

	message.setHandler("sbqForceSit", function(_,_, data)
		status.setStatusProperty("sbqForceSitData", data)
		status.addEphemeralEffect("sbqForceSit", 1, data.source)
	end)

	message.setHandler("sbqGetSeatInformation", function()
		return {
			mass = mcontroller.mass(),
			powerMultiplier = status.stat("powerMultiplier")
		}
	end)

	message.setHandler("sbqSucc", function(_,_, data)
		status.setStatusProperty("sbqSuccData", data)
		status.addEphemeralEffect("sbqSucc", 1, data.source)
	end)

	message.setHandler("sbqIsPreyEnabled", function(_,_, voreType)
		local preySettings = sb.jsonMerge(root.assetJson("/sbqGeneral.config:defaultPreyEnabled")[world.entityType(entity.id())], sb.jsonMerge((status.statusProperty("sbqPreyEnabled") or {}), (status.statusProperty("sbqOverridePreyEnabled")or {})))
		if preySettings.preyEnabled == false then return false end
		local enabled = true
		if type(voreType) == "table" then
			for i, voreType in ipairs(voreType) do
				enabled = enabled and preySettings[voreType]
			end
		else
			enabled = preySettings[voreType]
		end

		local currentData = status.statusProperty("sbqCurrentData") or {}
		return { enabled = preySettings[voreType], size = sbq.calcSize(), preyList = status.statusProperty("sbqPreyList"), type = currentData.type}
	end)

	message.setHandler("sbqGetPreyEnabled", function(_, _)
		local currentData = status.statusProperty("sbqCurrentData") or {}
		return sb.jsonMerge({size = sbq.calcSize(), preyList = status.statusProperty("sbqPreyList"), type = currentData.type}, sb.jsonMerge(root.assetJson("/sbqGeneral.config:defaultPreyEnabled")[world.entityType(entity.id())], sb.jsonMerge((status.statusProperty("sbqPreyEnabled") or {}), (status.statusProperty("sbqOverridePreyEnabled")or {}))))
	end)

	message.setHandler("sbqGetPreyEnabledSetting", function(_,_, setting)
		return sb.jsonMerge(root.assetJson("/sbqGeneral.config:defaultPreyEnabled")[world.entityType(entity.id())], sb.jsonMerge((status.statusProperty("sbqPreyEnabled") or {}), (status.statusProperty("sbqOverridePreyEnabled")or {})))[setting]
	end)


	message.setHandler("sbqProjectileSource", function (_,_, source)
		status.setStatusProperty("sbqProjectileSource", source)
	end)

	message.setHandler("sbqDigest", function (_,_,id)
		local currentData = status.statusProperty("sbqCurrentData") or {}
		if type(currentData.id) == "number" and world.entityExists(currentData.id) then
			world.sendEntityMessage(currentData.id, "sbqDigest", id)
		end
	end)
	message.setHandler("sbqSoftDigest", function (_,_,id)
		local currentData = status.statusProperty("sbqCurrentData") or {}
		if type(currentData.id) == "number" and world.entityExists(currentData.id) then
			world.sendEntityMessage(currentData.id, "sbqSoftDigest", id)
		end
	end)
	message.setHandler("sbqPreyList", function (_,_,preyList)
		status.setStatusProperty("sbqPreyList", preyList)
	end)

	message.setHandler("sbqGetSpeciesOverrideData", function (_,_)
		local data = { species = world.entitySpecies(entity.id()), gender = world.entityGender(entity.id())}
		return sb.jsonMerge(data, status.statusProperty("speciesAnimOverrideData") or {})
	end)

	message.setHandler("sbqMysteriousPotionTF", function (_,_, data, duration)
		status.setStatusProperty("sbqMysteriousPotionTFDuration", duration )
		mysteriousTFDuration = duration
		sbq.doMysteriousTF(data)
	end)
	message.setHandler("sbqEndMysteriousPotionTF", function (_,_)
		sbq.endMysteriousTF()
	end)

	message.setHandler("sbqApplyDigestEffects", function(_, _, effects, data, sourceEntityId)
		status.setStatusProperty("sbqDigestData", data)
		for i, effect in ipairs(effects) do
			status.addEphemeralEffect(effect, 1, sourceEntityId)
		end
	end)

	message.setHandler("sbqConsumeResource", function(_, _, resourceName, amount)
		if status.resourceLocked(resourceName) then return false end
		return status.overConsumeResource(resourceName, amount)
	end)

	message.setHandler("sbqGetResourcePercentage", function(_, _, resourceName)
		return status.resourcePercentage(resourceName)
	end)

	message.setHandler("sbqAddToResources", function(_, _, amount, resources, multipliers)
		local amountRemaining = amount
		for i, resource in ipairs(resources or {}) do
			if amountRemaining <= 0 then break end
			if status.isResource(resource) then
				local mul = ((multipliers or {})[i] or 1)
				local before = status.resource(resource) / mul
				status.giveResource(resource, (amountRemaining * mul))
				amountRemaining = (before + amountRemaining) - (status.resourceMax(resource) / mul)
			end
		end
	end)
	message.setHandler("sbqTakeFromResources", function(_, _, amount, resources, multipliers, thresholds)
		local amountRemaining = amount
		for i, resource in ipairs(resources or {}) do
			if amountRemaining <= 0 then break end
			if status.isResource(resource) then
				local threshold = ((thresholds or {})[i] or 0)
				if status.resourcePercentage(resource) > threshold then
					local mul = ((multipliers or {})[i] or 1)
					local before = status.resource(resource) / mul
					status.modifyResource(resource, -(amountRemaining * mul))
					amountRemaining = math.max((amountRemaining - before), 0)
					if resource == "energy" then
						status.setResourcePercentage("energyRegenBlock", math.max(status.resourcePercentage("energyRegenBlock"),0.1))
					end
				end
			end
		end
		return amount - amountRemaining
	end)


	message.setHandler("sbqGetDriverStat", function( _, _, stat)
		return status.stat(stat)
	end )

	message.setHandler("sbqDigestStore", function(_, _, location, uniqueId, item)
		if (not uniqueId) or (not item) or (not location) then return end
		local item = item
		local digestedStoredTable = status.statusProperty("sbqStoredDigestedPrey") or {}
		digestedStoredTable[location] = digestedStoredTable[location] or {}
		item.count = (item.count or 1) + ((digestedStoredTable[location][uniqueId] or {}).count or 0)
		digestedStoredTable[location][uniqueId] = item
		status.setStatusProperty("sbqStoredDigestedPrey", digestedStoredTable)
	end)

	message.setHandler("sbqCheckInfusion", function(_, _, location, locationData, pred, primaryLocation)
		local enabled = sb.jsonMerge(root.assetJson("/sbqGeneral.config:defaultPreyEnabled")[world.entityType(entity.id())], sb.jsonMerge((status.statusProperty("sbqPreyEnabled") or {}), (status.statusProperty("sbqOverridePreyEnabled")or {})))[locationData.infusionSetting]
		if not enabled then return end

		local uniqueId = world.entityUniqueId(entity.id())
		if locationData.infusionAccepts and locationData.infusionAccepts.characters then
			if type((locationData.infusionAccepts or {}).characters) == "table" then
				local continue
				for i, uuid in ipairs((locationData.infusionAccepts or {}).characters or {}) do
					if uuid == uniqueId then
						continue = true
						break
					end
				end
				if not continue then return end
			end
		end
		if (locationData.infusionAccepts or {}).rejectCharacters then
			if ((locationData.infusionAccepts or {}).rejectCharacters) == true then return end
			for i, uuid in ipairs((locationData.infusionAccepts or {}).rejectCharacters or {}) do
				if uuid == uniqueId then
					return
				end
			end
		end


		local template = locationData.infusionItem
		if type(template) == "string" then
			template = root.assetJson(template)
		end
		local itemDrop = sbq.generateItemDrop(pred, locationData.infuseText or "Infused By: ",
			template or root.assetJson("/sbqGeneral.config:npcEssenceTemplate"))
		world.sendEntityMessage(pred, "sbqReplaceInfusion", location, itemDrop, entity.id(), primaryLocation)
	end)

	message.setHandler("sbqSteppy", function(_, _, eid, steppyType, steppySize)
		local size = sbq.calcSize()
		if size <= (steppySize*0.4) then
			world.sendEntityMessage(eid, "sbqDidSteppy", entity.id(), steppyType)
		end
	end)

	mysteriousTFDuration = status.statusProperty("sbqMysteriousPotionTFDuration" )
end

local oldupdate = update
function update(dt)
	if oldupdate ~= nil then oldupdate(dt) end

	if type(mysteriousTFDuration) == "number" then
		mysteriousTFDuration = math.max(mysteriousTFDuration - dt, 0)
		if mysteriousTFDuration == 0 then
			sbq.endMysteriousTF()
		end
	end
end

function sbq.calcSize()
	local boundRectSize = rect.size(mcontroller.boundBox())
	local size = math.sqrt(boundRectSize[1] * boundRectSize[2]) / root.assetJson("/sbqGeneral.config:size") -- size is being based on the player, 1 prey would be math.sqrt(1.4x3.72) as that is the bound rect of the humanoid hitbox
	status.setStatusProperty("sbqSize", size)
	return size
end

function sbq.doMysteriousTF(data)
	if world.pointTileCollision(entity.position(), {"Null"}) then return end
	local overrideData = data or {}
	local currentData = status.statusProperty("speciesAnimOverrideData") or {}
	local customizedSpecies = status.statusProperty("sbqCustomizedSpecies") or {}
	local originalSpecies = world.entitySpecies(entity.id())
	local originalGender = world.entityGender(entity.id())

	if (not overrideData.species) or overrideData.species == "any" then
		local speciesList = root.assetJson("/interface/windowconfig/charcreation.config").speciesOrdering
		local validSpecies = false
		local blacklist = root.assetJson("/animOverrideBlacklist.config")
		while not validSpecies do
			overrideData.species = speciesList[math.random(#speciesList)]
			validSpecies = not blacklist[overrideData.species]
		end
	elseif overrideData.species == "originalSpecies" then
		overrideData.species = currentData.species or originalSpecies
	end
	local customData = customizedSpecies[overrideData.species]
	local isOriginalSpecies = (overrideData.species == originalSpecies or (customData or {}).species == originalSpecies)
	if isOriginalSpecies and not (overrideData.identity or overrideData.gender ~= originalGender) then
		return sbq.endMysteriousTF()
	end

	overrideData = sb.jsonMerge(customData or {}, overrideData)

	local genders = {"male", "female"}

	local genderswapAllow = sb.jsonMerge(root.assetJson("/sbqGeneral.config:defaultPreyEnabled")[world.entityType(entity.id())], sb.jsonMerge(status.statusProperty("sbqPreyEnabled") or {}, status.statusProperty("sbqOverridePreyEnabled") or {})).genderswapAllow
	if not genderswapAllow then
		overrideData.gender = currentData.gender or world.entityGender(entity.id())
	else
		if overrideData.gender == "random" then
			overrideData.gender = genders[math.random(2)]
		elseif not overrideData.gender or overrideData.gender == "noChange" then
			overrideData.gender = currentData.gender or world.entityGender(entity.id())
		elseif overrideData.gender == "swap" then
			local table = { male = "female", female = "male" }
			overrideData.gender = table[currentData.gender or world.entityGender(entity.id())]
		end
	end

	local success, speciesFile = pcall(root.assetJson, ("/species/"..overrideData.species..".species"))

	overrideData.identity = overrideData.identity or {}
	if success and not isOriginalSpecies then

		for i, data in ipairs(speciesFile.genders or {}) do
			if data.name == overrideData.gender then
				overrideData.identity.hairGroup = ((overrideData.identity.hairGroup ~= "") and overrideData.identity.hairGroup) or ((data.hairGroup ~= "") and data.hairGroup) or "hair"
				overrideData.identity.facialHairGroup = ((overrideData.identity.facialHairGroup ~= "") and overrideData.identity.facialHairGroup) or ((data.facialHairGroup ~= "") and data.facialHairGroup) or "facialHair"
				overrideData.identity.facialMaskGroup = ((overrideData.identity.facialMaskGroup ~= "") and overrideData.identity.facialMaskGroup) or ((data.facialMaskGroup ~= "") and data.facialMaskGroup) or "facialMask"
			if data.hair and data.hair[1] then
					overrideData.identity.hairType = overrideData.identity.hairType or data.hair[math.random(#data.hair)]
				end
				if data.facialHair and data.facialHair[1] then
					overrideData.identity.facialHairType = overrideData.identity.facialHairType or data.facialHair[math.random(#data.facialHair)]
				end
				if data.facialMask and data.facialMask[1] then
					overrideData.identity.facialMaskType = overrideData.identity.facialMaskType or data.facialMask[math.random(#data.facialMask)]
				end
			end
		end

		local undyColor = overrideData.identity.undyColor or ""
		if not overrideData.identity.undyColor and speciesFile.undyColor and speciesFile.undyColor[1] then
			local index = math.random(#speciesFile.undyColor)
			local colorTable = (speciesFile.undyColor or {})[index]
			if type(colorTable) == "table" then
				undyColor = "?replace"
				for color, replace in pairs(colorTable) do
					undyColor = undyColor..";"..color.."="..replace
				end
			end
			overrideData.identity.undyColor = undyColor
			overrideData.identity.undyColorIndex = index
		end

		local bodyColor = overrideData.identity.bodyColor or overrideData.identity.bodyDirectives or ""
		if not overrideData.identity.bodyColor and speciesFile.bodyColor and speciesFile.bodyColor[1] then
			local index = math.random(#speciesFile.bodyColor)
			local colorTable = (speciesFile.bodyColor or {})[index]
			if type(colorTable) == "table" then
				bodyColor = "?replace"
				for color, replace in pairs(colorTable) do
					bodyColor = bodyColor..";"..color.."="..replace
				end
			end
			overrideData.identity.bodyColorIndex = index
			overrideData.identity.bodyColor = bodyColor
		end

		local hairColor = overrideData.identity.hairColor or overrideData.identity.hairDirectives or ""
		if not overrideData.identity.hairColor and speciesFile.hairColor and speciesFile.hairColor[1] then
			local index = math.random(#speciesFile.hairColor)
			local colorTable = (speciesFile.hairColor or {})[index]
			if type(colorTable) == "table" then
				hairColor = "?replace"
				for color, replace in pairs(colorTable) do
					hairColor = hairColor..";"..color.."="..replace
				end
			end
			overrideData.identity.hairColorIndex = index
			overrideData.identity.hairColor = hairColor
		end

		if not overrideData.identity.hairDirectives then
			if speciesFile.headOptionAsHairColor then
				overrideData.identity.hairDirectives = hairColor
			else
				overrideData.identity.hairDirectives = bodyColor
			end
			if speciesFile.altOptionAsHairColor then
				overrideData.identity.hairDirectives = overrideData.identity.hairDirectives..undyColor
			end
			if speciesFile.bodyColorAsHairSubColor then
				overrideData.identity.hairDirectives = overrideData.identity.hairDirectives..bodyColor
			end
		end

		if not overrideData.identity.bodyDirectives then
			overrideData.identity.bodyDirectives = bodyColor
			if speciesFile.altOptionAsUndyColor then
				overrideData.identity.bodyDirectives = overrideData.identity.bodyDirectives..undyColor
			end
			if speciesFile.hairColorAsBodySubColor then
				overrideData.identity.bodyDirectives = overrideData.identity.bodyDirectives..hairColor
			end
		end


		if not overrideData.identity.facialHairDirectives then
			overrideData.identity.facialHairDirectives = overrideData.identity.hairDirectives
		end

		if not overrideData.identity.facialMaskDirectives then
			overrideData.identity.facialMaskDirectives = hairColor
			if speciesFile.bodyColorAsFacialMaskSubColor then
				overrideData.identity.facialMaskDirectives = overrideData.identity.facialMaskDirectives..bodyColor
			end
			if speciesFile.altColorAsFacialMaskSubColor then
				overrideData.identity.facialMaskDirectives = overrideData.identity.facialMaskDirectives..undyColor
			end
		end


		overrideData.identity.emoteDirectives = overrideData.identity.emoteDirectives or overrideData.identity.bodyDirectives
	end


	overrideData.mysteriousPotion = true
	overrideData.permanent = true
	overrideData.customAnimStatus = speciesFile.customAnimStatus

	if (not isOriginalSpecies and not customData) and not speciesFile.noUnlock then
		customizedSpecies[overrideData.species] = overrideData
		status.setStatusProperty("sbqCustomizedSpecies", customizedSpecies)
		world.sendEntityMessage(entity.id(), "sbqUnlockedSpecies")
	end

	local statusProperty = status.statusProperty("speciesAnimOverrideData") or {}
	if not statusProperty.mysteriousPotion then
		status.setStatusProperty("oldSpeciesAnimOverrideData", statusProperty)
		status.setStatusProperty("oldSpeciesAnimOverrideCategory", status.getPersistentEffects("speciesAnimOverride"))
	end

	status.setStatusProperty("speciesAnimOverrideData", overrideData)

	local currentEffect = (status.getPersistentEffects("speciesAnimOverride") or {})[1]
	local resultEffect = speciesFile.customAnimStatus or "speciesAnimOverride"
	if resultEffect == currentEffect then
		world.sendEntityMessage(entity.id(), "refreshAnimOverrides" )
	else
		status.clearPersistentEffects("speciesAnimOverride")
		status.setPersistentEffects("speciesAnimOverride", { resultEffect })
	end

	refreshOccupantHolder()
end

function refreshOccupantHolder()
	local currentData = status.statusProperty("sbqCurrentData") or {}
	if type(currentData.id) == "number" and world.entityExists(currentData.id) then
		world.sendEntityMessage(currentData.id, "reversion")
		if currentData.species == "sbqOccupantHolder" then
			world.spawnProjectile("sbqWarpInEffect", mcontroller.position(), entity.id(), { 0, 0 }, true)
		elseif type(currentData.species) == "nil" then
			world.sendEntityMessage(entity.id(), "sbqGetSpeciesVoreConfig")
		end
	else
		world.spawnProjectile("sbqWarpInEffect", mcontroller.position(), entity.id(), { 0, 0 }, true)
	end
end

function sbq.endMysteriousTF()
	status.setStatusProperty("sbqMysteriousPotionTFDuration", nil )
	mysteriousTFDuration = nil
	local oldData = status.statusProperty("oldSpeciesAnimOverrideData") or {}
	status.setStatusProperty("speciesAnimOverrideData", oldData)

	local currentEffect = (status.getPersistentEffects("speciesAnimOverride") or {})[1]
	local resultEffect = oldData.customAnimStatus or "speciesAnimOverride"
	if resultEffect == currentEffect then
		world.sendEntityMessage(entity.id(), "refreshAnimOverrides" )
	else
		status.clearPersistentEffects("speciesAnimOverride")
		status.setPersistentEffects("speciesAnimOverride", { resultEffect })
	end
	local originalSpeciesFile = root.assetJson("/species/"..(oldData.species or world.entitySpecies(entity.id()))..".species") or {}
	if originalSpeciesFile.statusEffects then
		status.setPersistentEffects("species", originalSpeciesFile.statusEffects or {})
	else
		status.clearPersistentEffects("species")
	end

	refreshOccupantHolder()
end

require("/scripts/SBQ_generate_drop.lua")
