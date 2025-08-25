function init()
	_ENV.supporterCreditsLabel:setText(table.concat(root.assetJson("/sbqSupporters.json") or {}, "\n"))

    _ENV.helpTabCommandsPanel:clearChildren()
	local children = {}
    for k, v in pairs(sbq.strings.helpCommand) do
        table.insert(children, { type = "label", text = "^cyan;" .. k })
        table.insert(children, { type = "label", text = v })
        table.insert(children, { type = "spacer", size = 5 })
    end
	_ENV.helpTabCommandsPanel:addChild({type = "layout", mode = "v", children = children})
end
