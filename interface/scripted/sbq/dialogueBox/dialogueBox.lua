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
function init()
	sbq.addRPC(world.sendEntityMessage(pane.sourceEntity(), "sbqActionList", "request", player.id()),function(actions)
		if actions and actions[1] then
			_ENV.actionButton:setVisible(true)
		end
	end)
	message.setHandler("sbqDialogueActionButtonVisible", function (_,_, visible)
		_ENV.actionButton:setVisible(visible)
	end)
	for _, script in ipairs(sbq.dialogueTree.dialogueStepScripts or {}) do
		require(script)
	end
	if (not sbq.settings) or ((not player.isAdmin()) and (sbq.parentEntityData and sbq.parentEntityData[2] and (player.uniqueId() ~= sbq.parentEntityData[1]))) then
		_ENV.settings:setVisible(false)
	end

	dialogueBox.refresh(sbq.dialogueTreeStart or ".greeting", sbq.dialogueTree, sbq.dialogueTree)
	inital = false
end

function update()
	local dt = script.updateDt()
	sbq.checkRPCsFinished(dt)
	sbq.checkTimers(dt)
	sbq.loopedMessage("interacted",pane.sourceEntity,"setInteracted",{player.id()})
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
		if (not data) or ((not player.isAdmin()) and data.parentEntityData[2] and (entity.uniqueId() ~= data.parentEntityData[1])) then
			pane.playSound("/sfx/interface/clickon_error.ogg")
		end
		player.interact("ScriptPane", { gui = {}, scripts = { "/metagui/sbq/build.lua" }, data = {sbq = data}, ui =  ("starbecue:entitySettings") }, pane.sourceEntity())
	end, function ()
		pane.playSound("/sfx/interface/clickon_error.ogg")
	end)
end

function _ENV.actionButton:onClick()
	sbq.addRPC(world.sendEntityMessage(pane.sourceEntity(), "sbqActionList", "request", player.id()), function (actions)
		if actions and actions[1] then
			local actionList = {}
			for _, action in ipairs(actions) do
				if action.available then
					local requestAction = function ()
						world.sendEntityMessage(pane.sourceEntity(), "sbqRequestAction", action.action, player.id(), true, table.unpack(action.args or {}) )
					end
					table.insert(actionList, {
						_ENV.metagui.formatText(action.name or (":" .. action.action)),
						requestAction,
						_ENV.metagui.formatText(action.requestDescription or (":"..action.action.."RequestDesc"))
					})
				else
					table.insert(actionList, {
						"^#555;^set;"..(_ENV.metagui.formatText(action.name or (":" .. action.action)) or ""),
						function() end,
						_ENV.metagui.formatText(action.requestDescription or (":"..action.action.."RequestDesc"))
					})
				end
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
	local name = dialogueProcessor.getRedirectedDialogue(option[1], true, sbq.settings, dialogue.prev, dialogue.prevTop)
	if unavailable then
		return {"^#555;^set;"..name, function () sbq.playErrorSound() end }
	end
	return {name, function ()
		dialogueBox.refresh(option[2])
	end }
end

function dialogueBox.refresh(path, dialogueTree, dialogueTreeTop)
	if path then
		if not dialogueProcessor.getDialogue(path, sbq.entityId(), sbq.settings, dialogueTree, dialogueTreeTop) then dialogue.finished = true return false end
	elseif dialogue.finished then return true
	else
		dialogue.position = dialogue.position + 1
		if dialogue.position >= #dialogue.result.dialogue then
			dialogue.finished = true
		end
	end
	local results = dialogueProcessor.processDialogueResults()
	if results.imagePortrait then
		_ENV.imagePortrait:setVisible(true)
		_ENV.entityPortraitPanel:setVisible(false)
		_ENV.imagePortrait:setFile(sb.assetPath(results.imagePortrait, results.imagePath or "/"))
		_ENV.nameLabel.width = _ENV.imagePortrait.imgSize[1]
	elseif results.entityPortrait then
		_ENV.imagePortrait:setVisible(false)
		_ENV.entityPortraitPanel:setVisible(true)
		_ENV.nameLabel.width = _ENV.entityPortraitPanel.size[1]
		local canvas = widget.bindCanvas(_ENV.entityPortraitCanvas.backingWidget)
		canvas:clear()
		canvas:drawDrawables(world.entityPortrait(results.source, results.entityPortrait), vec2.sub(vec2.div(_ENV.entityPortraitCanvas.size, 2), {0,6*4}), {4,4})
	else
		_ENV.imagePortrait:setVisible(false)
		_ENV.entityPortraitPanel:setVisible(false)
		_ENV.nameLabel.width = nil
	end
	if results.name then
		_ENV.nameLabel:setText(results.name)
	else
		_ENV.nameLabel:setText("")
	end
	_ENV.dialogueCont:setText(results.buttonText)

	dialogueBox.text = sb.replaceTags(results.dialogue, results.tags)
	dialogueBox.textSound = results.textSound
	dialogueBox.textSpeed = results.textSpeed
	dialogueBox.textPosition = 1
	if inital then
		sbq.timer(nil, 0.25, dialogueBox.scrollText)
	else
		dialogueBox.scrollText()
	end

	dialogueBox.dismissAfterTimer(results.dismissTime)
	return true
end
function dialogueBox.scrollText()
	if dialogueBox.textPosition > string.len(dialogueBox.text) then return end
	while not dialogueBox.findNextRealCharacter() do
	end
	_ENV.dialogueLabel:setText(string.sub(dialogueBox.text, 1, dialogueBox.textPosition))
	if dialogueBox.textSound and string.sub(dialogueBox.text, dialogueBox.textPosition) ~= " " then
		local sound = dialogueBox.textSound
		while type(sound) == "table" do
			sound = sound[math.random(#sound)]
		end
		pane.playSound(sound)
	end

	dialogueBox.textPosition = dialogueBox.textPosition + 1
	sbq.timer(nil, (dialogueBox.textSpeed or 1) * 0.025, dialogueBox.scrollText)
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
