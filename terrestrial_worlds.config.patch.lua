
function patch(config)
	if sb.jsonQuery(config, "planetTypes.garden.layers.surface.dungeons") then
		table.insert(config.planetTypes.garden.layers.surface.dungeons, { 1.0, "sbqGardenFireplace" })
	end
	if sb.jsonQuery(config, "config.planetTypes.garden.layers.surface.dungeonCountRange") then
		config.planetTypes.garden.layers.surface.dungeonCountRange[1] = config.planetTypes.garden.layers.surface.dungeonCountRange[1] + 1
		config.planetTypes.garden.layers.surface.dungeonCountRange[2] = config.planetTypes.garden.layers.surface.dungeonCountRange[2] + 1
	end
	return config
end
