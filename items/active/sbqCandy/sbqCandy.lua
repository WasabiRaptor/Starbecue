function fireTriggered()
	world.sendEntityMessage(player.id(), "sbqGetTieredUpgrade", config.getParameter("sbqTieredUpgrade"), config.getParameter("level") or 1, config.getParameter("bonus") or 1)
end
