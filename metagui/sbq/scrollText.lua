require("/scripts/any/SBQ_RPC_handling.lua")
local textSound = _ENV.metagui.cfg.textSound
local text = _ENV.metagui.cfg.text
local textSpeed = _ENV.metagui.cfg.speed
local textPosition = 1
local textVolume = _ENV.metagui.cfg.volume or 1
function init()
	scrollText()
end
function update()
	sbq.checkTimers(script.updateDt())
end

function scrollText()
	if textPosition > string.len(text) then return end
	while not findNextRealCharacter() do
	end
	_ENV.dialogueLabel:setText(string.sub(text, 1, textPosition))
	if textSound and string.sub(text, textPosition) ~= " " then
		local sound = textSound
		while type(sound) == "table" do
			sound = sound[math.random(#sound)]
		end
		pane.playSound(sound, nil, textVolume)
	end

	textPosition = textPosition + 1
	sbq.timer(nil, (textSpeed or 1) * sbq.config.textSpeedMul, scrollText)
end
function findNextRealCharacter()
	local char = string.sub(text, textPosition, textPosition)
	if char == "\\" then
		textPosition = textPosition + 2
	elseif char == "^" then
		textPosition = string.find(text, ";", textPosition, true) + 1
	else
		return true
	end
end
