function init()
	_ENV.supporterCreditsLabel:setText(table.concat(root.assetJson("/sbqSupporters.json") or {}, "\n"))
end
