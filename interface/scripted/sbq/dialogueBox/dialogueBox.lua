dialogueBox = {}
function init()
	sbq.name = world.entityName(pane.sourceEntity())
    _ENV.nameLabel:setText(sbq.name)

    sbq.entityId = pane.sourceEntity
	_ENV.actionButton:setVisible(sbq.actionButtons ~= nil)

	for _, script in ipairs(sbq.dialogueStepScripts or {}) do
		require(script)
    end
	if sbq.entityPortrait then
		_ENV.dialoguePortraitCanvas:setVisible(true)
	else
		_ENV.dialoguePortrait:setVisible(true)
	end
	-- sbq.dialogueTree = sbq.data.dialogueTree

	-- sbq.updateDialogueBox(sbq.data.dialogueTreeStart or ".greeting", sbq.dialogueTree)
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
		dialogueProcessor.getDialogue(path, pane.sourceEntity(), sbq.settings, dialogueTree, dialogueTreeTop)
	else
		if #dialogue.result.dialogue >= dialogue.position then
			dialogue.finished = true
		else
			dialogue.position = dialogue.position + 1
		end
	end

	-- _ENV.nameLabel:setText(name)
	-- _ENV.dialogueCont:setText(buttonText)

	-- if portrait then
	-- 	if sbq.entityPortrait then
	-- 		local canvas = widget.bindCanvas( _ENV.dialoguePortraitCanvas.backingWidget )
	-- 		canvas:drawDrawables(world.entityPortrait(speaker, portrait), vec2.div(_ENV.dialoguePortraitCanvasvasWidget.size, 2))
	-- 	else
	-- 		_ENV.dialoguePortrait:setFile(sb.assetPath(portrait, dialogue.result.portraitPath or sbq.data.portraitPath or "/"))
	-- 	end
	-- end

	-- _ENV.dialogueLabel:setText(sb.replaceTags(printDialogue, tags), dialogue.result.textSounds[dialogue.position] or dialogue.result.textSounds[#dialogue.result.textSounds])
    -- world.sendEntityMessage(speaker, "sbqSay", printDialogue, tags, imagePortrait, emote)

	return path, dialogueTree, dialogueTreeTop
end

function dialogueBox.dismissAfterTimer(time)
	if not time then
		sbq.timerList.dismissAfterTime = nil
	else
		sbq.forceTimer("dismissAfterTime", time, function()
			if not dialogue.finished then
				dialogueBox.refresh()
			elseif dialogue.result.jump then
				local path = dialogue.result.jump
				dialogueProcessor.finishDialogue()
				dialogueBox.refresh(path)
			else
				pane.dismiss()
			end
		end)
	end
end
