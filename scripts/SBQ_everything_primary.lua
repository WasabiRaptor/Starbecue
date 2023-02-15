local mysteriousTFDuration
require("/scripts/rect.lua")

function sbq.everything_primary()
	message.setHandler("sbqApplyStatusEffects", function(_,_, statlist)
		for statusEffect, data in pairs(statlist) do
			status.setStatusProperty(statusEffect, data.property)
			status.addEphemeralEffect(statusEffect, data.power, data.source)
		end
	end)
	message.setHandler("sbqRemoveStatusEffects", function(_,_, statlist)
		for _, statusEffect in ipairs(statlist) do
			status.removeEphemeralEffect(statusEffect)
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
		local boundRectSize = rect.size(mcontroller.boundBox())
		local size = math.sqrt(boundRectSize[1] * boundRectSize[2]) / root.assetJson("/sbqGeneral.config:size") -- size is being based on the player, 1 prey would be math.sqrt(1.4x3.72) as that is the bound rect of the humanoid hitbox
		status.setStatusProperty("sbqSize", size)
		return { enabled = preySettings[voreType], size = size, preyList = status.statusProperty("sbqPreyList")}
	end)

	message.setHandler("sbqGetPreyEnabled", function(_,_)
		return sb.jsonMerge(root.assetJson("/sbqGeneral.config:defaultPreyEnabled")[world.entityType(entity.id())], sb.jsonMerge((status.statusProperty("sbqPreyEnabled") or {}), (status.statusProperty("sbqOverridePreyEnabled")or {})))
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

	message.setHandler("sbqApplyDigestEffect", function(_, _, effectConfig, data, sourceEntityId)
		status.setStatusProperty("sbqDigestData", data)
		status.addEphemeralEffect(effectConfig, 1, sourceEntityId)
	end)

	message.setHandler("sbqConsumeResource", function(_, _, resourceName, amount)
		return status.consumeResource(resourceName, amount)
	end)

	message.setHandler("sbqDigestStore", function(_, _, location, uniqueId, item)
		if (not uniqueId) or (not item) or (not location) then return end
		local digestedStoredTable = status.statusProperty("sbqStoredDigestedPrey") or {}
		digestedStoredTable[location] = digestedStoredTable[location] or {}
		digestedStoredTable[location][uniqueId] = item
		status.setStatusProperty("sbqStoredDigestedPrey", digestedStoredTable)
	end)

	message.setHandler("sbqCheckInfusion", function(_, _, location, locationData, pred, primaryLocation)
		local enabled = sb.jsonMerge(root.assetJson("/sbqGeneral.config:defaultPreyEnabled")[world.entityType(entity.id())], sb.jsonMerge((status.statusProperty("sbqPreyEnabled") or {}), (status.statusProperty("sbqOverridePreyEnabled")or {})))[locationData.infusionSetting]
		if not enabled then return end
		local template = locationData.infusionItem
		if type(template) == "string" then
			template = root.assetJson(template)
		end
		local itemDrop = sbq.generateItemDrop(pred, locationData.infuseText or "Infused By: ",
			template or root.assetJson("/sbqGeneral.config:npcEssenceTemplate"))
		world.sendEntityMessage(pred, "sbqReplaceInfusion", location, itemDrop, entity.id(), primaryLocation)
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
					overrideData.identity.hairGroup = overrideData.identity.hairGroup or data.hairGroup or "hair"
					overrideData.identity.facialHairGroup = overrideData.identity.facialHairGroup or data.facialHairGroup or "facialHair"
					overrideData.identity.facialMaskGroup = overrideData.identity.facialMaskGroup or data.facialMaskGroup or "facialMask"

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

		local bodyColor = overrideData.identity.bodyDirectives or ""
		if not overrideData.identity.bodyDirectives and speciesFile.bodyColor and speciesFile.bodyColor[1] then
			local index = math.random(#speciesFile.bodyColor)
			local colorTable = (speciesFile.bodyColor or {})[index]
			if type(colorTable) == "table" then
				bodyColor = "?replace"
				for color, replace in pairs(colorTable) do
					bodyColor = bodyColor..";"..color.."="..replace
				end
			end
			overrideData.identity.bodyColorIndex = index
			overrideData.identity.bodyDirectives = bodyColor

			if speciesFile.altOptionAsUndyColor then
				overrideData.identity.bodyDirectives = overrideData.identity.bodyDirectives..undyColor
			end
		end

		local hairColor = overrideData.identity.hairDirectives or ""
		if not overrideData.identity.hairDirectives and speciesFile.hairColor and speciesFile.hairColor[1] then
			local index = math.random(#speciesFile.hairColor)
			local colorTable = (speciesFile.hairColor or {})[index]
			if type(colorTable) == "table" then
				hairColor = "?replace"
				for color, replace in pairs(colorTable) do
					hairColor = hairColor..";"..color.."="..replace
				end
			end
			overrideData.identity.hairColorIndex = index
			if speciesFile.headOptionAsHairColor then
				overrideData.identity.hairDirectives = hairColor
			else
				overrideData.identity.hairDirectives = overrideData.identity.bodyDirectives
			end
			if speciesFile.altOptionAsHairColor then
				overrideData.identity.hairDirectives = overrideData.identity.hairDirectives..undyColor
			end
			if speciesFile.hairColorAsBodySubColor then
				overrideData.identity.bodyDirectives = overrideData.identity.bodyDirectives..hairColor
			end
			if speciesFile.bodyColorAsHairSubColor then
				overrideData.identity.hairDirectives = overrideData.identity.hairDirectives..overrideData.identity.bodyDirectives
			end
		end

		if not overrideData.identity.facialHairDirectives then
			overrideData.identity.facialHairDirectives = overrideData.identity.facialHairDirectives or overrideData.identity.hairDirectives
			if speciesFile.bodyColorAsFacialHairSubColor then
				overrideData.identity.facialMaskDirectives = overrideData.identity.facialMaskDirectives..overrideData.identity.bodyDirectives
			end
		end
		if not overrideData.identity.facialMaskDirectives then
			overrideData.identity.facialMaskDirectives = overrideData.identity.facialMaskDirectives or overrideData.identity.hairDirectives
			if speciesFile.bodyColorAsFacialMaskSubColor then
				overrideData.identity.facialMaskDirectives = overrideData.identity.facialMaskDirectives..overrideData.identity.bodyDirectives
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
