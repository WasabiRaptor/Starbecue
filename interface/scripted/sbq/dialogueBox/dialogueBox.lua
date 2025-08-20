require("/scripts/any/SBQ_dialogue.lua")
require("/scripts/any/SBQ_dialogue_scripts.lua")
require("/scripts/player/SBQ_player_dialogue_scripts.lua")
dialogueBox = {
	text = "",
	textPosition = 1,
	textSpeed = 1,
	textSound = nil,
}
local inital = true
local doScrollText = true
local doCustomFont = true
local drawable
function init()
	drawable = pane.drawable()
	_ENV.metagui.inputData.sbq.dialogue = nil
	sbq.addRPC(world.sendEntityMessage(pane.sourceEntity(), "sbqActionList", "request", player.id()), function(actions)
		if actions and actions[1] then
			_ENV.actionButton:setVisible(not sbq.noActions)
		else
			_ENV.actionButton:setVisible(false)
		end
	end, function ()
		_ENV.actionButton:setVisible(false)
    end)

	-- message.setHandler("sbqCloseDialogueBox", function ()
	-- 	pane.dismiss()
    -- end)

	doScrollText = world.sendEntityMessage(player.id(), "sbqGetSetting", "scrollText"):result()
	doCustomFont = world.sendEntityMessage(player.id(), "sbqGetSetting", "customFont"):result()

	for _, script in ipairs(sbq.dialogueTree.dialogueStepScripts or {}) do
		require(script)
	end
	if (not sbq.settings) or ((not player.isAdmin()) and (sbq.parentEntityData and sbq.parentEntityData[2] and (player.uniqueId() ~= sbq.parentEntityData[1]))) then
		_ENV.settings:setVisible(false)
	end

	if sbq.dialogue then
		dialogue = sbq.dialogue
		dialogue.position = dialogue.position - 1
		dialogue.finished = false
		dialogueBox.refresh()
	else
		dialogueBox.refresh(sbq.dialogueTreeStart or ".greeting", sbq.dialogueTree, sbq.dialogueTree)
	end

	inital = false
end

function update()
	local dt = script.updateDt()
	sbq.checkRPCsFinished(dt)
	sbq.checkTimers(dt)
	sbq.loopedMessage("interacted", pane.sourceEntity(), "sbqSetInteracted", {player.id()})
end

function _ENV.dialogueLabel:setText(t)
	local old = self.text
	self.text = _ENV.metagui.formatText(t)
	if self.text ~= old then
		self:queueRedraw()
		-- if I don't do this bullshit it lags the hell out of the game because it recalculates everything
		local ugh = self.parent.parent
		self.parent.parent = nil
		self.parent:queueGeometryUpdate()
		self.parent.parent = ugh
	end
end

function _ENV.close:onClick()
	pane.dismiss()
end

function _ENV.settings:onClick()
	sbq.addRPC(world.sendEntityMessage(pane.sourceEntity(), "sbqSettingsPageData", player.id()), function(data)
		if (not data) or ((not player.isAdmin()) and data.parentEntityData[2] and (player.uniqueId() ~= data.parentEntityData[1])) then
			sbq.playErrorSound()
		end
		player.interact("ScriptPane", { gui = {}, scripts = { "/metagui/sbq/build.lua" }, data = {sbq = data}, ui =  ("starbecue:entitySettings") }, pane.sourceEntity())
	end, function ()
		sbq.playErrorSound()
	end)
end

function _ENV.actionButton:onClick()
	sbq.addRPC(world.sendEntityMessage(pane.sourceEntity(), "sbqActionList", "request", player.id()), function (actions)
		if actions and actions[1] then
			local actionList = {}
			for _, action in ipairs(actions) do
				local requestAction = function ()
					world.sendEntityMessage(pane.sourceEntity(), "sbqRequestAction", false, action.action, player.id(), table.unpack(action.args or {}) )
				end
				table.insert(actionList, {
					action.available and sbq.getString(action.name or (":" .. action.action)) or "^#555;^set;"..(sbq.getString(action.name or (":" .. action.action)) or ""),
					requestAction,
					sbq.getString(action.requestDescription or (":"..action.action.."RequestDesc"))
				})
			end
			_ENV.metagui.dropDownMenu(actionList, 2)
		else
			_ENV.actionButton:setVisible(false)
		end
	end)
end

function _ENV.dialogueCont:onClick()
	if not dialogue.finished then
		dialogueBox.refresh()
	end
	if dialogue.result.callScript then
		local path = world.sendEntityMessage(player.id(), dialogue.result.callScript, pane.sourceEntity(), table.unpack(dialogue.result.callScriptArgs or {})):result()
		if type(path) == "string" then
			dialogueBox.refresh(path)
			return
		end
	end
	if dialogue.result.options then
		if dialogueBox.listOptions(dialogue.result.options) then return end
	end
	if dialogue.result.jump then
		dialogueBox.refresh(dialogue.result.jump)
		return
	end
end

function dialogueBox.listOptions(options)
	local menu = {}
	for _, option in ipairs(options) do
		local res = dialogueBox.validateOption(option)
		if res then table.insert(menu, res) end
	end
	if menu[1] then
		_ENV.metagui.dropDownMenu(menu,
			dialogue.result.optionsColumns or 2,
			dialogue.result.optionsW,
			dialogue.result.optionsH,
			dialogue.result.optionsS,
			dialogue.result.optionsAlign
		)
		return true
	end
end

function dialogueBox.validateOption(option)
	local unavailable = false
	for _, v in ipairs(option[3] or {}) do
		local res = dialogueOptionScripts[v[1]](table.unpack(v))
		if not res then
			return
		elseif res == "unavailable" then
			unavailable = true
		end
	end
	local name = dialogueProcessor.getRedirectedDialogue(option[1], true, sbq.settings, dialogue.prev, dialogue.prevTop)
	if unavailable then
		return {"^#555;^set;"..name, function () sbq.playErrorSound() end }
	end
	return {name, function ()
		dialogueBox.refresh(option[2])
	end }
end

local dismissTime
function dialogueBox.refresh(path, dialogueTree, dialogueTreeTop)
	if path then
		if not dialogueProcessor.getDialogue(path, player.id(), dialogueTree, dialogueTreeTop) then
			dialogue.finished = true
			return false
		end
	elseif dialogue.finished then
		return true
	else
		dialogue.position = dialogue.position + 1
	end
	if not dialogue.result.dialogue then
		dialogue.finished = true
		return
	end
	if dialogue.position >= #dialogue.result.dialogue then
		dialogue.finished = true
	end
	local results = dialogueProcessor.processDialogueResults()
    if results.imagePortrait then
        _ENV.imagePortrait:setVisible(true)
        _ENV.entityPortraitPanel:setVisible(false)
        _ENV.imagePortrait:setFile(sbq.assetPath(results.imagePortrait, results.imagePath or "/"))
        _ENV.nameLabel.width = _ENV.imagePortrait.imgSize[1]
    elseif results.entityPortrait then
        _ENV.imagePortrait:setVisible(false)
        _ENV.entityPortraitPanel:setVisible(true)
        _ENV.nameLabel.width = _ENV.entityPortraitPanel.size[1]
        local canvas = widget.bindCanvas(_ENV.entityPortraitCanvas.backingWidget)
        canvas:clear()
        local portrait = world.entityPortrait(results.source, results.entityPortrait)
        if portrait then
			portrait = drawable.scaleAll(portrait, {4,4})
			local bounds = drawable.boundBoxAll(portrait, true)
			local center = rect.center(bounds)
			canvas:drawDrawables(portrait, vec2.sub(vec2.div(_ENV.entityPortraitCanvas.size, 2), center))
        end
    else
        _ENV.imagePortrait:setVisible(false)
        _ENV.entityPortraitPanel:setVisible(false)
        _ENV.nameLabel.width = nil
    end
    local nameFont = results.nameFont or results.font
    local nameTextDirectives = (results.nameDirectives or results.textDirectives or "").."^set;"
	if nameFont then
		nameTextDirectives = "^font="..nameFont..";"..nameTextDirectives
	end
	if results.name then
		_ENV.nameLabel:setText(nameTextDirectives..results.name)
	else
		_ENV.nameLabel:setText("")
	end
	_ENV.dialogueCont:setText(results.buttonText)

	local textDirectives = (results.textDirectives or "").."^set;"
	if results.font and doCustomFont then
		textDirectives = "^font="..results.font..";"..textDirectives
	end

	dialogueBox.text = sb.replaceTags(textDirectives..results.dialogue, results.tags)
	dialogueBox.textSound = results.textSound
	dialogueBox.textSpeed = results.textSpeed
	dialogueBox.textVolume = results.textVolume or 1
	dialogueBox.textPosition = 1

	dismissTime = results.dismissTime
	if dismissTime and not dialogue.result.jump then
		_ENV.dialogueCont:setVisible(false)
	end
	sbq.timerList.dismissAfterTime = nil

	sbq.debugLogInfo(dialogueBox.text, 1)
	if doScrollText then
		if inital then
			sbq.timer(nil, 0.25, dialogueBox.scrollText)
		else
			dialogueBox.scrollText()
		end
	else
		_ENV.dialogueLabel:setText(dialogueBox.text)
		dialogueBox.textPosition = utf8.len(dialogueBox.text) + 1
		dialogueBox.dismissAfterTimer(dismissTime)
	end
	return true
end

function dialogueBox.scrollText()
	if dialogueBox.textPosition > utf8.len(dialogueBox.text) then
		return
	end
	while not dialogueBox.findNextRealCharacter() do
	end
	local pos1 = utf8.offset(dialogueBox.text, dialogueBox.textPosition)
	local pos2 = utf8.offset(dialogueBox.text, dialogueBox.textPosition + 1) - 1
	if dialogueBox.textPosition == utf8.len(dialogueBox.text) then
		pos2 = string.len(dialogueBox.text)
	end
	_ENV.dialogueLabel:setText(string.sub(dialogueBox.text, 1, pos2))

	if dialogueBox.textSound and string.sub(dialogueBox.text, pos1, pos2) ~= " " then
		local sound = dialogueBox.textSound
		while type(sound) == "table" do
			sound = sound[math.random(#sound)]
		end
		pane.playSound(sound, nil, dialogueBox.textVolume)
	end

	dialogueBox.textPosition = dialogueBox.textPosition + 1
	sbq.timer(nil, (dialogueBox.textSpeed or 1) * sbq.config.textSpeedMul, dialogueBox.scrollText)
end


function dialogueBox.findNextRealCharacter()
	local pos1 = utf8.offset(dialogueBox.text, dialogueBox.textPosition)
    local pos2 = utf8.offset(dialogueBox.text, dialogueBox.textPosition + 1) - 1
	if dialogueBox.textPosition == utf8.len(dialogueBox.text) then
		pos2 = string.len(dialogueBox.text)
	end
	local char = string.sub(dialogueBox.text, pos1, pos2)

	local semicolon = string.find(dialogueBox.text, ";", pos2+1, true)
	local space = string.find(dialogueBox.text, " ", pos2+1, true)

	if char == "^" and semicolon and ((not space) or (space > semicolon)) then
		dialogueBox.textPosition = utf8.len(dialogueBox.text, 1, semicolon + 1) or utf8.len(dialogueBox.text) or math.huge
	else
		return true
	end
end


function dialogueBox.dismissAfterTimer(time)
	if not time then
		sbq.timerList.dismissAfterTime = nil
	else
		sbq.forceTimer("dismissAfterTime", time, function()
			if not dialogue.finished then
				dialogueBox.refresh()
			elseif dialogue.result.jump and (dialogue.result.jump ~= dialogue.path) then
				dialogueBox.refresh(dialogue.result.jump, dialogue.prev)
			else
				pane.dismiss()
			end
		end)
	end
end
