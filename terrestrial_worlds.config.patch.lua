
function patch(config)
	table.insert(config.planetTypes.garden.layers.surface.dungeons, {1.0, "sbqGardenFireplace"})
	config.planetTypes.garden.layers.surface.dungeonCountRange[1] = #config.planetTypes.garden.layers.surface.dungeons
	config.planetTypes.garden.layers.surface.dungeonCountRange[2] = #config.planetTypes.garden.layers.surface.dungeons
	return config
end
