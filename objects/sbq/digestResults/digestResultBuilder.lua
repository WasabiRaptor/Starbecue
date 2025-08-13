sbq = {}
require("/scripts/any/SBQ_util.lua")
function build(directory, config, parameters, level, seed)
	sbq.strings = root.assetJson("/sbqStrings.config")
	local preyIdentity = sbq.query(parameters, {"npcArgs", "npcParam", "identity"})
	if config.speciesVariants and preyIdentity then
		config = sb.jsonMerge(config, config.speciesVariants[preyIdentity.species] or {})
	end
	if not parameters.generated then
		parameters.generated = true
		local preyName = (preyIdentity or {}).name

		setupReplaceColors(config, parameters, parameters.predIdentity)
		setupReplaceColors(config, parameters, preyIdentity)


		if sbq.strings[config.descType] then
			if sbq.strings[config.descType].forgetful then
				parameters.forgetful = math.random() < 0.25
			end
			if parameters.forgetful and parameters.predName and sbq.strings[config.descType].forgetful then
				parameters.descIndex = math.random(#sbq.strings[config.descType].forgetful.desc)
			elseif preyName and parameters.predName and sbq.strings[config.descType].both then
				parameters.descIndex = math.random(#sbq.strings[config.descType].both.desc)
			elseif preyName and sbq.strings[config.descType].prey then
				parameters.descIndex = math.random(#sbq.strings[config.descType].prey.desc)
			elseif parameters.predName and sbq.strings[config.descType].pred then
				parameters.descIndex = math.random(#sbq.strings[config.descType].pred.desc)
			else
				parameters.descIndex = math.random(#sbq.strings[config.descType].default.desc)
			end
		end

		local imagePath = config.orientations[1].image
		local replaceTags = sb.jsonMerge(config.imageKeys, parameters.imageKeys or {}, {
			variant = tostring(math.random(1, config.spriteVariants or 1))
		})
		for k, v in pairs(preyIdentity or {}) do
			if type(v) == "string" then
				replaceTags[k] = v
			end
		end

		if not root.assetOrigin(sb.replaceTags(imagePath, replaceTags), directory) then
			replaceTags.species = "any"
		end
		if not root.assetOrigin(sb.replaceTags(imagePath, replaceTags), directory) then
			replaceTags.variant = "1"
		end
		parameters.imageKeys = replaceTags
		parameters.inventoryIcon = sb.replaceTags(config.inventoryIcon, parameters.imageKeys)
		parameters.animationCustom = parameters.animationCustom or {}
		parameters.animationCustom.globalTagDefaults = sb.jsonMerge(parameters.animationCustom.globalTagDefaults or {}, replaceTags)

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
		if sbq.strings[config.descType] then
			local i = parameters.descIndex
			local name = {}
			local desc = {}
			local descVariant = "default"
			if parameters.forgetful and parameters.predName and sbq.strings[config.descType].forgetful then
				name = sbq.strings[config.descType].forgetful.name or {}
				desc = sbq.strings[config.descType].forgetful.desc or {}
				descVariant = "forgetful"
			elseif preyName and parameters.predName and sbq.strings[config.descType].both then
				name = sbq.strings[config.descType].both.name or {}
				desc = sbq.strings[config.descType].both.desc or {}
				descVariant = "both"
			elseif preyName and sbq.strings[config.descType].prey then
				name = sbq.strings[config.descType].prey.name or {}
				desc = sbq.strings[config.descType].prey.desc or {}
				descVariant = "prey"
			elseif parameters.predName and sbq.strings[config.descType].pred then
				name = sbq.strings[config.descType].pred.name or {}
				desc = sbq.strings[config.descType].pred.desc or {}
			else
				name = sbq.strings[config.descType].default.name or {}
				desc = sbq.strings[config.descType].default.desc or {}
			end
			parameters.shortdescription = sb.replaceTags(name[i] or name[1] or (":"..config.descType.."."..descVariant..".name"), tags)
			parameters.description = sb.replaceTags(desc[i] or desc[1] or (":"..config.descType.."."..descVariant..".desc"), tags)
		else
			parameters.shortdescription = sbq.getString(":"..config.descType.."Name")
			parameters.description = sbq.getString(":"..config.descType.."Desc")
		end
	end

	return config, parameters
end

function setupReplaceColors(config, parameters, identity)
	if not identity then return end
    local speciesFile = root.speciesConfig(identity.species or "")
	if speciesFile and speciesFile.useImagePathSpecies then
		speciesFile = root.speciesConfig(identity.imagePath or identity.species or "")
	end
	if not speciesFile then return end
	if not speciesFile.baseColorPalette then return end
	local identityTags = {

	}
	for k, v in pairs(identity) do
		if type(v) == "string" then
			identityTags[k] = v
		end
	end

	local replaceTags = {
		replaceMap = "",
		replaceColors = (speciesFile.dropColorString and sb.replaceTags(speciesFile.dropColorString, identityTags)) or (identity.bodyColor or identity.bodyDirectives)..(identity.altColor or "")..(identity.hairColor or identity.hairDirectives)
	}
	for k, v in pairs(config.baseColorPalette) do
		replaceTags.replaceMap = replaceTags.replaceMap..sbq.replace(v, speciesFile.baseColorPalette[k])
	end
	parameters.imageKeys = sb.jsonMerge(config.imageKeys, replaceTags)
	parameters.inventoryIcon = sb.replaceTags(config.inventoryIcon, parameters.imageKeys)
	parameters.animationCustom = parameters.animationCustom or {}
	parameters.animationCustom.globalTagDefaults = sb.jsonMerge((config.animationCustom or {}).globalTagDefaults or {}, replaceTags)

end
