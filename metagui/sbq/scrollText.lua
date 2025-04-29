require("/scripts/any/SBQ_RPC_handling.lua")
local textSound = _ENV.metagui.cfg.textSound
local text = _ENV.metagui.cfg.text
local textSpeed = _ENV.metagui.cfg.speed
local textPosition = 1
local textVolume = _ENV.metagui.cfg.volume or 1
function init()
	player.setScriptContext("starbecue")
	if player.callScript("sbq.checkSetting", "scrollText") then
		scrollText()
	else
		_ENV.dialogueLabel:setText(dialogueBox.text)
	end
end

function update()
	sbq.checkTimers(script.updateDt())
end

function scrollText()
    if textPosition > utf8.len(text) then
        return
    end
    while not findNextRealCharacter() do
    end
    local pos1 = utf8.offset(text, textPosition)
    local pos2 = utf8.offset(text, textPosition + 1) - 1
	if textPosition == utf8.len(text) then
		pos2 = string.len(text)
	end
    _ENV.dialogueLabel:setText(string.sub(text, 1, pos2))

    if textSound and string.sub(text, pos1, pos2) ~= " " then
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
    local pos1 = utf8.offset(text, textPosition)
    local pos2 = utf8.offset(text, textPosition + 1) - 1
	if textPosition == utf8.len(text) then
		pos2 = string.len(text)
	end
    local char = string.sub(text, pos1, pos2)

    local semicolon = string.find(text, ";", textPosition, true)
	local space = string.find(text, " ", textPosition, true)

	if char == "^" and semicolon and ((not space) or (space > semicolon)) then
		textPosition = utf8.len(text, semicolon + 1) or math.huge
	else
		return true
	end
end
