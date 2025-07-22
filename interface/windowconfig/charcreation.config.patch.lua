
function patch(config)
    local speciesOrdering = {
		"sbq/FFWizard/hellhound",
		"sbq/vaporeon",
		"sbq/flareon",
		"sbq/meowscarada",
		"sbq/nickit_anthro"
		-- "sbq/slime",
    }
    for _, v in ipairs(speciesOrdering) do
        table.insert(config.speciesOrdering, v)
    end
	return config
end
