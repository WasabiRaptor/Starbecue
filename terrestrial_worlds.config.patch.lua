
function patch(config)
	if sb.jsonQuery(config, "planetTypes.garden.layers.surface.dungeons") then
		table.insert(config.planetTypes.garden.layers.surface.dungeons, { 1.0, "sbqGardenFireplace" })
		if sb.jsonQuery(config, "planetTypes.garden.layers.surface.dungeonCountRange") then
			config.planetTypes.garden.layers.surface.dungeonCountRange[1] = #config.planetTypes.garden.layers.surface.dungeons
			config.planetTypes.garden.layers.surface.dungeonCountRange[2] = #config.planetTypes.garden.layers.surface.dungeons
		end
	end
	return config
end
