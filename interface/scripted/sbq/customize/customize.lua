local identity = _ENV.metagui.inputData.identity
local parameters = _ENV.metagui.inputData.parameters
local choices = jarray()
local randomSource = sb.makeRandomSource()
function init()
	if not parameters.choices then
		choices[1] = (identity.gender == "male") and 0 or 1
		for i = 2, 10 do
			choices[i] = randomSource:randu64()
		end
	else
		for i = 1, 10 do
			choices[i] = parameters.choices[i]
		end
	end
	_ENV.nameBox:setText(identity.name)

	local speciesConfig = root.speciesConfig(identity.species)
	_ENV.bodyColorLabel:setText(speciesConfig.charGenTextLabels[1])
	_ENV.hairChoiceLabel:setText(speciesConfig.charGenTextLabels[2])
	_ENV.shirtChoiceLabel:setText(speciesConfig.charGenTextLabels[3])
	_ENV.pantsChoiceLabel:setText(speciesConfig.charGenTextLabels[4])
	_ENV.altyLabel:setText(speciesConfig.charGenTextLabels[5])
	_ENV.headyLabel:setText(speciesConfig.charGenTextLabels[6])
	_ENV.shirtColorLabel:setText(speciesConfig.charGenTextLabels[7])
	_ENV.pantsColorLabel:setText(speciesConfig.charGenTextLabels[8])
	_ENV.personalityLabel:setText(speciesConfig.charGenTextLabels[10])

	_ENV.genderMale:setIconDrawables(
		{
			{ image = "/interface/title/button.png" },
			{ image = speciesConfig.genders[1].image}
		},
		{
			{ image = "/interface/title/selected.png" },
			{ image = speciesConfig.genders[1].image}
		}
	)
	_ENV.genderFemale:setIconDrawables(
		{
			{ image = "/interface/title/button.png" },
			{ image = speciesConfig.genders[2].image}
		},
		{
			{ image = "/interface/title/selected.png" },
			{ image = speciesConfig.genders[2].image}
		}
	)
	_ENV.genderMale:draw()
	_ENV.genderFemale:draw()
	_ENV.genderMale:selectValue(choices[1])
end

function applyChoices()
	identity, parameters = root.createHumanoid(_ENV.nameBox.text, identity.species, table.unpack(choices))
	world.sendEntityMessage(pane.sourceEntity(), "sbqSetIdentity", identity, parameters)
end

function _ENV.randomizeAll:onClick()
	local randomSource = sb.makeRandomSource()
	for i = 2, 10 do
		choices[i] = randomSource:randu64()
	end
	applyChoices()
end

function _ENV.randomizeName:onClick()
	local speciesConfig = root.speciesConfig(identity.species)
	_ENV.nameBox:setText(root.generateName(speciesConfig.nameGen[(identity.gender == "male") and 1 or 2]))
	applyChoices()
end

function setGender()
	choices[1] = _ENV.genderMale:getGroupValue()
	applyChoices()
end

_ENV.genderMale.onClick = setGender
_ENV.genderFemale.onClick = setGender

function choiceSpinner(i, choiceName)
	local left = _ENV[choiceName.."Left"]
	local right = _ENV[choiceName.."Right"]
	local random = _ENV[choiceName.."Random"]
	function left:onClick()
		choices[i] = choices[i] - 1
		applyChoices()
	end
	function right:onClick()
		choices[i] = choices[i] + 1
		applyChoices()
	end
	function random:onClick()
		choices[i] = randomSource:randu64()
		applyChoices()
	end

end

choiceSpinner(2, "bodyColor")
choiceSpinner(4, "hairChoice")
choiceSpinner(6, "shirtChoice")
choiceSpinner(8, "pantsChoice")
choiceSpinner(10, "personality")

choiceSpinner(3, "alty")
choiceSpinner(5, "heady")
choiceSpinner(7, "shirtColor")
choiceSpinner(9, "pantsColor")
