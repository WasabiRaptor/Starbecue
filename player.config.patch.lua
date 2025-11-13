function patch(config)
	config = sb.jsonMerge(config, {
		defaultCodexes = {
			["sbq/Ferrilata_/Ferri"] = { "protectorate1", "protectorate2" }
		},
		statusControllerSettings = {
			stats = {
				sbqLustScriptMax = {
					baseValue = 0.33
				},
				sbqLustScriptDelta = {
					baseValue = 0.0583
				},
				sbqLustDelta = {
					baseValue = 0
				},
				sbqRestScriptDelta = {
					baseValue = -0.0583
				},
				sbqRestDelta = {
					baseValue = 0
				}
			},
			resources = {
				sbqLust = {
					deltaStat = "sbqLustDelta",
					initialPercentage = 0.0,
					maxValue = 100
				},
				sbqRest = {
					deltaStat = "sbqRestDelta",
					initialPercentage = 1.0,
					maxValue = 100
				}
			}
		}
	})
	local blueprints = {
		{ item= "sbqController" },
		{ item= "sbqRequester" },
		{ item= "sbqCandy", parameters={level=1} },
		{ item= "sbqCandy", parameters={level=2} },
		{ item= "sbqCandy", parameters={level=3} },
		{ item= "sbqCandy", parameters={level=4} },
		{ item= "sbqCandy", parameters={level=5} },
		{ item= "sbqCandy", parameters={level=6} }
	}
	for _, v in ipairs(blueprints) do
		table.insert(config.defaultBlueprints.tier1, v)
	end
	table.insert(config.statusControllerSettings.primaryScriptSources, "/scripts/player/SBQ_player_primary.lua")
	table.insert(config.companionsConfig.scripts, "/scripts/player/SBQ_player_companion.lua")
	table.insert(config.deploymentConfig.scripts, "/scripts/player/SBQ_player_deployment.lua")
	config.genericScriptContexts.starbecue = "/scripts/player/SBQ_player_generic.lua"

	return config
end
