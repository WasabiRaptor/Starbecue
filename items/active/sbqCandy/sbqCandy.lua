function fireTriggered()
	player.setScriptContext("starbecue")
	player.callScript("sbq.getTieredUpgrade", config.getParameter("sbqTieredUpgrade"), config.getParameter("level") or 1, config.getParameter("bonus") or 1)
end
