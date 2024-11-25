sbq = {}
require("/scripts/any/SBQ_util.lua")
function build(directory, config, parameters, level, seed)
	if not parameters.generated then
		parameters.generated = true
		local preyIdentity = sbq.query(parameters, {"npcArgs", "npcParam", "identity"})
		local preyName = (preyIdentity or {}).name

		setupReplaceColors(config, parameters, parameters.predIdentity)
		setupReplaceColors(config, parameters, preyIdentity)

		parameters.forgetful = math.random() < 0.25
		if parameters.forgetful and parameters.predName and config.replaceDescForgetful then
			parameters.descIndex = math.random(#config.replaceDescForgetful)
		elseif preyName and parameters.predName and config.replaceDescPredPrey then
			parameters.descIndex = math.random(#config.replaceDescPredPrey)
		elseif preyName and config.replaceDescPrey then
			parameters.descIndex = math.random(#config.replaceDescPrey)
		elseif parameters.predName and config.replaceDescPred then
			parameters.descIndex = math.random(#config.replaceDescPred)
		end

		if config.variants and preyIdentity then
			local species = "any"
			if preyIdentity.species and config.variants and config.variants[preyIdentity.species] then
				species = preyIdentity.species
			end
			local replaceTags = {
				species = species,
				variant = tostring(math.random(config.variants[species]))
			}
			parameters.imageKeys = sb.jsonMerge(parameters.imageKeys or {}, replaceTags)
			parameters.inventoryIcon = sb.replaceTags(config.inventoryIcon, parameters.imageKeys)
			parameters.animationCustom = parameters.animationCustom or {}
			parameters.animationCustom.globalTagDefaults = sb.jsonMerge(parameters.animationCustom.globalTagDefaults or {}, replaceTags)
		end
	end
	if parameters.directives then -- because of the old ones
		parameters.imageKeys = sb.jsonMerge(config.imageKeys, {
			replaceColors = parameters.directives
		})
		parameters.inventoryIcon = sb.replaceTags(config.inventoryIcon, parameters.imageKeys)
	else
		local preyIdentity = sbq.query(parameters, {"npcArgs", "npcParam", "identity"})
		local preyName = (preyIdentity or {}).name
		local tags = {
			preyName = preyName,
			predName = parameters.predName,
		}
		if parameters.forgetful and parameters.predName and config.replaceDescForgetful then
			parameters.shortdescription = sb.replaceTags(sbq.getString(config.replaceShortDescForgetful), tags)
			parameters.description = sb.replaceTags(sbq.getString(config.replaceDescForgetful[parameters.descIndex or 1]), tags)
		elseif preyName and parameters.predName and config.replaceDescPredPrey then
			parameters.shortdescription = sb.replaceTags(sbq.getString(config.replaceShortDescPredPrey), tags)
			parameters.description = sb.replaceTags(sbq.getString(config.replaceDescPredPrey[parameters.descIndex or 1]), tags)
		elseif preyName and config.replaceDescPrey then
			parameters.shortdescription = sb.replaceTags(sbq.getString(config.replaceShortDescPrey), tags)
			parameters.description = sb.replaceTags(sbq.getString(config.replaceDescPrey[parameters.descIndex or 1]), tags)
		elseif parameters.predName and config.replaceDescPred then
			parameters.shortdescription = sb.replaceTags(sbq.getString(config.replaceShortDescPred), tags)
			parameters.description = sb.replaceTags(sbq.getString(config.replaceDescPred[parameters.descIndex or 1]), tags)
		else
			parameters.shortdescription = sbq.getString(config.shortdescription)
			parameters.description = sbq.getString(config.description)
		end
	end

	if sbq.query(parameters, {"npcArgs", "npcParam", "scriptConfig", "initialStorage", "sbqSettings"}) then
		parameters.npcArgs.npcParam.scriptConfig.initialStorage.sbqSettings = nil
	end
	if sbq.query(parameters, {"npcArgs", "npcParam", "scriptConfig", "sbqSettings", "recentlyDigested"}) then
		parameters.npcArgs.npcParam.scriptConfig.sbqSettings.recentlyDigested = nil
	end
	if sbq.query(parameters, {"npcArgs", "npcParam", "scriptConfig", "sbqSettings", "infuseSlots"}) then
		parameters.npcArgs.npcParam.scriptConfig.sbqSettings.infuseSlots = nil
	end

	return config, parameters
end

function setupReplaceColors(config, parameters, identity)
	if not identity then return end
	local speciesFile = root.speciesConfig(identity.species or "")
	if not speciesFile then return end
	if not speciesFile.baseColorMap then return end
	local replaceTags = {
		replaceMap = "",
		replaceColors = (identity.bodyColor or identity.bodyDirectives)..(identity.altColor or "")..(identity.hairColor or identity.hairDirectives)
	}
	for k, v in pairs(config.baseColorMap) do
		replaceTags.replaceMap = replaceTags.replaceMap..sbq.replace(v, speciesFile.baseColorMap[k])
	end
	parameters.imageKeys = sb.jsonMerge(config.imageKeys, replaceTags)
	parameters.inventoryIcon = sb.replaceTags(config.inventoryIcon, parameters.imageKeys)
	parameters.animationCustom = parameters.animationCustom or {}
	parameters.animationCustom.globalTagDefaults = sb.jsonMerge((config.animationCustom or {}).globalTagDefaults or {}, replaceTags)

end
