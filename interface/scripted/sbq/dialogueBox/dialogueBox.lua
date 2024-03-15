dialogueBox = {
	text = "",
	textPosition = 1,
	textSpeed = 1,
	textSound = nil,
}
function init()
	_ENV.actionButton:setVisible(sbq.actionButtons ~= nil)
	for _, script in ipairs(sbq.dialogueStepScripts or {}) do
		require(script)
	end
	if sbq.entityPortrait then
		_ENV.dialoguePortraitCanvas:setVisible(true)
	else
		_ENV.dialoguePortrait:setVisible(true)
	end

	dialogueBox.refresh(sbq.dialogueTreeStart or ".greeting", sbq.dialogueTree, sbq.dialogueTree)
end

function update()
	local dt = script.updateDt()
	sbq.checkRPCsFinished(dt)
	sbq.checkTimers(dt)
end

function _ENV.close:onClick()
	pane.dismiss()
end
function _ENV.dialogueCont:onClick()
	if not dialogue.finished then
		dialogueBox.refresh()
	end
	if dialogue.result.callScript then
		player.setScriptContext(dialogue.result.scriptContext or "starbecue")
		local path = player.callScript(dialogue.result.callScript, pane.sourceEntity(), table.unpack(dialogue.result.callScriptArgs or {}))
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
	if unavailable then
		return {"^#555;"..option[1], function () sbq.playErrorSound() end }
	end
	return {option[1], function ()
		dialogueBox.refresh(option[2])
	end }
end

function dialogueBox.refresh(path, _dialogueTree, _dialogueTreeTop)
	dialogueTree = _dialogueTree or dialogue.prev
	dialogueTreeTop = _dialogueTreeTop or sbq.dialogueTree

	if path then
		if not dialogueProcessor.getDialogue(path, sbq.entityId(), sbq.settings, dialogueTree, dialogueTreeTop) then return end
	elseif dialogue.finished then return
	else
		dialogue.position = dialogue.position + 1
		if dialogue.position >= #dialogue.result.dialogue then
			dialogue.finished = true
		end
	end
	local results = dialogueProcessor.processDialogueResults()
	_ENV.nameLabel:setText(results.name)
	_ENV.dialogueCont:setText(results.buttonText)

	if results.imagePortrait then
		_ENV.dialoguePortrait:setVisible(true)
		_ENV.dialoguePortraitCanvas:setVisible(false)
		_ENV.dialoguePortrait:setFile(sb.assetPath(results.imagePortrait, results.imagePath or "/"))
	elseif results.entityPortrait then
		_ENV.dialoguePortrait:setVisible(false)
		_ENV.dialoguePortraitCanvas:setVisible(true)
		local canvas = widget.bindCanvas( _ENV.dialoguePortraitCanvas.backingWidget )
		canvas:drawDrawables(world.entityPortrait(results.source, results.entityPortrait), vec2.div(_ENV.dialoguePortraitCanvasvasWidget.size, 2))
	end

	dialogueBox.text = sb.replaceTags(results.dialogue, results.tags)
	dialogueBox.textSound = results.textSound
	dialogueBox.textSpeed = results.textSpeed
	dialogueBox.textPosition = 1
	dialogueBox.scrollText()
end
function dialogueBox.scrollText()
	if dialogueBox.textPosition > string.len(dialogueBox.text) then return end
	while not dialogueBox.findNextRealCharacter() do
	end
	_ENV.dialogueLabel:setText(string.sub(dialogueBox.text, 1, dialogueBox.textPosition))
	if dialogueBox.textSound then
		pane.playSound(dialogueBox.textSound)
	end

	dialogueBox.textPosition = dialogueBox.textPosition + 1
	sbq.timer(nil,dialogueBox.textSpeed/60,dialogueBox.scrollText)
end
function dialogueBox.findNextRealCharacter()
	local char = string.sub(dialogueBox.text, dialogueBox.textPosition, dialogueBox.textPosition)
	if char == "\\" then
		dialogueBox.textPosition = dialogueBox.textPosition + 2
	elseif char == "^" then
		dialogueBox.textPosition = string.find(dialogueBox.text, ";", dialogueBox.textPosition, true) + 1
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
			elseif dialogue.result.jump then
				dialogueBox.refresh(dialogue.result.jump, dialogue.prev)
			else
				pane.dismiss()
			end
		end)
	end
end
