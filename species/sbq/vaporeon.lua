-- these are just the names of the variables internally and how they're used on the creation screen, do whatever you want with them here!
-- but probably put name species and gender as the ones supplied, thats probably a good idea
-- I've supplied the bare minimum as a template here, do with it what you will
local function wrap(index, array)
	if index < #array then return index end
	return math.fmod(index, #array)
end
function create(name, species, genderIndex, primaryColor, neckFinnColor, bellyColor, beansColor, dorsalFinnColor, neckFinnStyle, earFinnColor, pantsColor, personality, ...)
	-- these values are zero indexed!

	local speciesConfig = root.speciesConfig(species)
	local humanoidConfig = sb.jsonMerge(root.assetJson(speciesConfig.humanoidConfig or "/humanoid.config"), speciesConfig.humanoidOverrides or {})


	genderIndex = wrap(genderIndex, speciesConfig.genders)
	local gender = speciesConfig.genders[genderIndex + 1]

	primaryColor = wrap(primaryColor, speciesConfig.bodyColor)
	neckFinnColor = wrap(neckFinnColor, speciesConfig.neckFinnColor)
	dorsalFinnColor = wrap(dorsalFinnColor, speciesConfig.dorsalFinnColor)
	bellyColor = wrap(bellyColor, speciesConfig.bellyColor)
	beansColor = wrap(beansColor, speciesConfig.beansColor)
	earFinnColor = wrap(earFinnColor, speciesConfig.earFinnColor)

	neckFinnStyle = wrap(neckFinnStyle, speciesConfig.neckFinnStyle)

	personality = wrap(personality, humanoidConfig.personalities)

	local directives = ""

	directives = directives .. (speciesConfig.bodyColor[primaryColor + 1])
	directives = directives .. (speciesConfig.bellyColor[bellyColor + 1])
	directives = directives .. (speciesConfig.beansColor[beansColor + 1])
	directives = directives .. (speciesConfig.neckFinnColor[neckFinnColor + 1])
	directives = directives .. (speciesConfig.dorsalFinnColor[dorsalFinnColor + 1])
	directives = directives .. (speciesConfig.earFinnColor[earFinnColor + 1])


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
		facialHairGroup = "mane",
		facialHairType = speciesConfig.neckFinnStyle[neckFinnStyle+1],
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
		choices = { genderIndex, primaryColor, neckFinnColor, bellyColor, beansColor, dorsalFinnColor, neckFinnStyle, earFinnColor, pantsColor, personality, ... },
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
