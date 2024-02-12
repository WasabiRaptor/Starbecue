
function sbq.setupTransformationMessages()
	message.setHandler("sbqDoTransformation", function (_,_, ...)
		sbq.doTransformation(...)
	end)
	message.setHandler("sbqEndMysteriousPotionTF", function (_,_)
		sbq.revertTF()
    end)
	message.setHandler("sbqGetIdentity", function (_,_)
		return humanoid.getIdentity()
	end)
	message.setHandler("sbqDigestDrop", function(_, _, itemDrop)
		local itemDrop = itemDrop
		local identity = humanoid.getIdentity()
		local species = humanoid.species()
		local speciesFile = root.speciesConfig(species)
		itemDrop.parameters.predSpecies = species
		itemDrop.parameters.predDirectives = (identity.bodyDirectives or "") .. (identity.hairDirectives or "")
		itemDrop.parameters.predColorMap = speciesFile.baseColorMap
		world.spawnItem(itemDrop, mcontroller.position())
	end)

end


function sbq.doTransformation(newIdentity, duration, perma, ...)
	if world.pointTileCollision(entity.position(), {"Null"}) then return end
	local currentIdentity =	humanoid.getIdentity()
    local speciesIdentites = status.statusProperty("sbqSpeciesIdentities") or {}
    local originalSpecies = status.statusProperty("sbqOriginalSpecies")
    local originalGender = status.statusProperty("sbqOriginalGender")

    if not originalSpecies then
		originalSpecies = humanoid.species()
        status.setStatusProperty("sbqOriginalSpecies", originalSpecies)
        speciesIdentites[originalSpecies] = currentIdentity
		status.setStatusProperty("sbqSpeciesIdentities", speciesIdentites)
	end
    if not originalGender then
		originalGender = humanoid.gender()
		status.setStatusProperty("sbqOriginalGender", originalGender)
    end

	if sbq.settings.genderTF then
		if newIdentity.gender == "random" then
			newIdentity.gender = ({"male", "female"})[math.random(2)]
		elseif newIdentity.gender == "swap" then
            newIdentity.gender = ({ male = "female", female = "male" })[currentIdentity.gender]
        else
			newIdentity.gender = currentIdentity.gender
        end
    else
		newIdentity.gender = currentIdentity.gender
    end

	if sbq.settings.speciesTF then
		if newIdentity.species == "any" then
			local speciesList = root.assetJson("/interface/windowconfig/charcreation.config").speciesOrdering
			newIdentity.species = speciesList[math.random(#speciesList)]
		elseif newIdentity.species == "originalSpecies" then
            newIdentity.species = originalSpecies
        else
			newIdentity.species = currentIdentity.species
        end
    else
		newIdentity.species = currentIdentity.species
	end

    newIdentity = sb.jsonMerge(
        humanoid.randomIdentity(newIdentity.species, newIdentity.personalityIndex, newIdentity.seed),
        newIdentity,
		((not newIdentity.force) and speciesIdentites[newIdentity.species]) or {}
	)

	local speciesFile = root.speciesConfig(newIdentity.species)

	if (not speciesIdentites[newIdentity.species]) and not speciesFile.noUnlock then
		speciesIdentites[newIdentity.species] = newIdentity
		status.setStatusProperty("sbqSpeciesIdentities", speciesIdentites)
		world.sendEntityMessage(entity.id(), "sbqUnlockedSpecies")
	end

    humanoid.setIdentity(newIdentity)

	if duration and not (sbq.settings.indefineiteTF) then
		sbq.forceTimer("revertTF", (duration or 5) * 60, sbq.revertTF)
    end
	if sbq.settings.permanentTF and perma then
		status.setStatusProperty("sbqOriginalSpecies", newIdentity.species)
		status.setStatusProperty("sbqOriginalGender", newIdentity.gender)
	end
end

function sbq.revertTF()
	local currentData = humanoid.getIdentity()
    local originalSpecies = status.statusProperty("sbqOriginalSpecies") or humanoid.species()
	local originalGender = status.statusProperty("sbqOriginalGender") or humanoid.gender()
    local speciesIdentities = status.statusProperty("sbqSpeciesIdentities") or {}
    local customData = speciesIdentities[originalSpecies] or humanoid.randomIdentity(originalSpecies, currentData.personalityIndex)
	customData.gender = originalGender
	humanoid.setIdentity(customData)
end
