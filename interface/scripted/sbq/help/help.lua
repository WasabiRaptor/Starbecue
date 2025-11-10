function init()
    _ENV.supporterCreditsLabel:setText(table.concat(root.assetJson("/sbqSupporters.json") or {}, "\n"))
	if _ENV.metagui.inputData.helpPage then
		_ENV.mainTabField.tabs[_ENV.metagui.inputData.helpPage]:select()
	end
end
