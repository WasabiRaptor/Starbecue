-- these are just the names of the variables internally and how they're used on the creation screen, do whatever you want with them here!
-- but probably put name species and gender as the ones supplied, thats probably a good idea
-- I've supplied the bare minimum as a template here, do with it what you will
function create(name, species, genderIndex, furColor, hairColor, eyeColor, hairStyle, beansColor, shirtColor, pantsChoice, pantsColor, personality, ...)
	-- these values are zero indexed!

	local speciesConfig = root.speciesConfig(species)
	local humanoidConfig = sb.jsonMerge(root.assetJson(speciesConfig.humanoidConfig or "/humanoid.config"), speciesConfig.humanoidOverrides or {})


	genderIndex = math.fmod(genderIndex, #speciesConfig.genders)
	local gender = speciesConfig.genders[genderIndex+1]
	furColor = math.fmod(furColor, #speciesConfig.furColor)
	eyeColor = math.fmod(eyeColor, #speciesConfig.eyeColor)
	beansColor = math.fmod(beansColor, #speciesConfig.beansColor)
	hairColor = math.fmod(hairColor, #speciesConfig.hairColor)
	hairStyle = math.fmod(hairStyle, #speciesConfig.hairStyle)
	personality = math.fmod(personality, #humanoidConfig.personalities)

	local directives = ""

	directives = directives..(speciesConfig.furColor[furColor+1])
	directives = directives..(speciesConfig.beansColor[beansColor+1])
	directives = directives..(speciesConfig.hairColor[hairColor+1])

	local personalityIdle, personalityArmIdle, personalityHeadOffset, personalityArmOffset = table.unpack(humanoidConfig.personalities[personality+1])

	local identity = {
		name = name,
		species = species,
		gender = gender.name,
		hairGroup = "hair",
		hairType = speciesConfig.hairStyle[hairStyle+1],
		hairDirectives = directives,
		bodyDirectives = directives,
		emoteDirectives = (speciesConfig.eyeColor[eyeColor+1]) .. directives,
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
		choices = { genderIndex, furColor, hairColor, eyeColor, hairStyle, beansColor, shirtColor, pantsChoice, pantsColor, personality, ... },
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
