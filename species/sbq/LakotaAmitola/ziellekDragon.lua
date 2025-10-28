-- these are just the names of the variables internally and how they're used on the creation screen, do whatever you want with them here!
-- but probably put name species and gender as the ones supplied, thats probably a good idea
-- I've supplied the bare minimum as a template here, do with it what you will
local function wrap(index, length, secondary, secondaryLength)
	if not index then
		index = math.floor(wrap(secondary, secondaryLength * length) / secondaryLength)
	end
	index = math.abs(index)
	if index < length then return index end
	return math.fmod(index, length)
end
function create(name, species, genderIndex, primaryColor, accentColor, hornColor, fluffColor, bellyColor, beansColor, eyeColor, pantsColor, personality, ...)
	-- these values are zero indexed!

	local speciesConfig = root.speciesConfig(species)
	local humanoidConfig = sb.jsonMerge(root.assetJson(speciesConfig.humanoidConfig or "/humanoid.config"), speciesConfig.humanoidOverrides or {})


	genderIndex = wrap(genderIndex, #speciesConfig.genders)
	local gender = speciesConfig.genders[genderIndex + 1]

	primaryColor = wrap(primaryColor, #speciesConfig.bodyColor)
	accentColor = wrap(accentColor, #speciesConfig.accentColor)
	bellyColor = wrap(bellyColor, #speciesConfig.bellyColor)
	hornColor = wrap(hornColor, #speciesConfig.hornColor)
	fluffColor = wrap(fluffColor, #speciesConfig.fluffColor)
	eyeColor = wrap(eyeColor, #speciesConfig.eyeColor)
	beansColor = wrap(beansColor, #speciesConfig.beansColor)

	personality = wrap(personality, #humanoidConfig.personalities)

	local directives = ""

	directives = directives .. (speciesConfig.bodyColor[primaryColor + 1])
	directives = directives .. (speciesConfig.accentColor[accentColor + 1])
	directives = directives .. (speciesConfig.bellyColor[bellyColor + 1])
	directives = directives .. (speciesConfig.fluffColor[fluffColor + 1])
	directives = directives .. (speciesConfig.hornColor[hornColor + 1])
	directives = directives .. (speciesConfig.eyeColor[eyeColor + 1])
	directives = directives .. (speciesConfig.beansColor[beansColor + 1])


	local personalityIdle, personalityArmIdle, personalityHeadOffset, personalityArmOffset = table.unpack(humanoidConfig.personalities[personality+1])

	local identity = {
		name = name,
		species = species,
		gender = gender.name,
		hairGroup = "",
		hairType = "",
		hairDirectives = directives,
		bodyDirectives = directives,
		emoteDirectives = directives,
		facialHairGroup = "",
		facialHairType = "",
		facialHairDirectives = directives,
		facialMaskGroup = "",
		facialMaskType = "",
		facialMaskDirectives = directives,
		personalityIdle = personalityIdle,
		personalityArmIdle = personalityArmIdle,
		personalityHeadOffset = personalityHeadOffset,
		personalityArmOffset = personalityArmOffset,
		color = {51, 117, 237, 255},
	}
	local parameters = {
		choices = { genderIndex, primaryColor, accentColor, hornColor, fluffColor, bellyColor, beansColor, eyeColor, pantsColor, personality, ... },
		--this you can do a lot with, see the humanoid build script
	}
	local armor = {
		head = nil,
		chest = nil,
		legs = nil,
		back = nil,
		headCosmetic = nil,
		chestCosmetic = nil,
		legsCosmetic = nil,
		backCosmetic = nil,
		cosmetic1 = nil,
		cosmetic2 = nil,
		cosmetic3 = nil,
		cosmetic4 = nil,
		cosmetic5 = nil,
		cosmetic6 = nil,
		cosmetic7 = nil,
		cosmetic8 = nil,
		cosmetic9 = nil,
		cosmetic10 = nil,
		cosmetic11 = nil,
		cosmetic12 = nil,
	}
	return identity, parameters, armor
end
