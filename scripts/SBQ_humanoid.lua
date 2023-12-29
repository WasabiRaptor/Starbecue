
function sbq.doMysteriousTF(data, duration)
	if world.pointTileCollision(entity.position(), {"Null"}) then return end
	local overrideData = data or {}
	local currentData =	 humanoid.getIdentity()
    local customizedSpecies = status.statusProperty("sbqCustomizedSpecies") or {}

	overrideData.personalityIndex = overrideData.personalityIndex or currentData.personalityIndex

    local originalSpecies = status.statusProperty("sbqOriginalSpecies")
	local originalGender = status.statusProperty("sbqOriginalGender")
    if not originalSpecies then
		originalSpecies = humanoid.species()
		status.setStatusProperty("sbqOriginalSpecies", originalSpecies)
	end
    if not originalGender then
		originalGender = humanoid.gender()
		status.setStatusProperty("sbqOriginalGender", originalGender)
	end

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

    local customData = customizedSpecies[overrideData.species] or {}
    if customData.identity then
		-- this is to fix old data from older versions of sbq
        customData = sb.jsonMerge(customData, customData.identity)
        customData.identity = nil
		customizedSpecies[overrideData.species] = nil
	end

	overrideData = sb.jsonMerge(customData or {}, overrideData)

	local genders = {"male", "female"}

	local genderswapAllow = sb.jsonMerge(root.assetJson("/sbqGeneral.config:defaultPreyEnabled")[world.entityType(entity.id())], sb.jsonMerge(status.statusProperty("sbqPreyEnabled") or {}, status.statusProperty("sbqOverridePreyEnabled") or {})).genderswapAllow
	if not genderswapAllow then
		overrideData.gender = currentData.gender
	else
		if overrideData.gender == "random" then
			overrideData.gender = genders[math.random(2)]
		elseif not overrideData.gender or overrideData.gender == "noChange" then
			overrideData.gender = currentData.gender
		elseif overrideData.gender == "swap" then
			local table = { male = "female", female = "male" }
			overrideData.gender = table[currentData.gender]
		end
    end

    overrideData = sb.jsonMerge(humanoid.randomIdentity(overrideData.species, overrideData.personalityIndex, overrideData.seed), overrideData)

	local speciesFile = root.speciesConfig(overrideData.species)

	if (not customizedSpecies[overrideData.species]) and not speciesFile.noUnlock then
		customizedSpecies[overrideData.species] = overrideData
		status.setStatusProperty("sbqCustomizedSpecies", customizedSpecies)
		world.sendEntityMessage(entity.id(), "sbqUnlockedSpecies")
	end

    humanoid.setIdentity(overrideData)

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
    local originalSpecies = status.statusProperty("sbqOriginalSpecies") or humanoid.species()
	local originalGender = status.statusProperty("sbqOriginalGender") or humanoid.gender()
    local customizedSpecies = status.statusProperty("sbqCustomizedSpecies") or {}
    local customData = customizedSpecies[originalSpecies]
	if not customData then return end
	customData.gender = originalGender
	humanoid.setIdentity(customData)

	refreshOccupantHolder()
end
