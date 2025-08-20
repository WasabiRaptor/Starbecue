function fireTriggered()
	world.sendEntityMessage(player.id(), "sbqSetTieredUpgrade", config.getParameter("sbqTieredUpgrade"), config.getParameter("level") or 1, config.getParameter("bonus") or 1)
end
