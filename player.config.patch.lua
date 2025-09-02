function patch(config)
    config = sb.jsonMerge(config, {
		defaultCodexes = {
			["sbq/LokiVulpix/Auri"] = { "protectorate1", "protectorate2" },
			["sbq/LokiVulpix/Loki"] = { "protectorate1", "protectorate2" },
			["sbq/Auroria/Auroria"] = { "protectorate1", "protectorate2" },
			["sbq/ambi_sykhar/Ambi"] = { "protectorate1", "protectorate2" },
			["sbq/Zygahedron/Zevi"] = { "protectorate1", "protectorate2" },
			["sbq/Fevix/Sandy"] = { "protectorate1", "protectorate2" },
			["sbq/vaporeonGiant"] = { "protectorate1", "protectorate2" },
			["sbq/LokiVulpix/Socks"] = { "protectorate1", "protectorate2" },
			["sbq/FFWizard/Helena"] = { "protectorate1", "protectorate2" },
			["sbq/FFWizard/hellhound"] = { "protectorate1", "protectorate2" },
			["sbq/LokiVulpix/Clover"] = { "protectorate1", "protectorate2" },
			["sbq/Xeronious/Batty"] = { "protectorate1", "protectorate2" },
			["sbq/Ferrilata_/Ferri"] = { "protectorate1", "protectorate2" },
			["sbq/AkariKaen/Akari"] = { "protectorate1", "protectorate2" },
			["sbq/slime"] = { "protectorate1", "protectorate2" },
			["sbq/Xeronious/Kaiju"] = { "protectorate1", "protectorate2" },
			["sbq/IcyVixen/Fray"] = { "protectorate1", "protectorate2" },
			["sbq/LakotaAmitola/ziellekDragon"] = { "protectorate1", "protectorate2" },
			["sbq/LakotaAmitola/Lakota"] = { "protectorate1", "protectorate2" },
			["sbq/Bestethan/Dex"] = { "protectorate1", "protectorate2" },
			["sbq/naga"] = { "protectorate1", "protectorate2" }
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
