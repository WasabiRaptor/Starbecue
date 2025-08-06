
function patch(config)
    local speciesOrdering = {
		"sbq/FFWizard/hellhound",
		-- "sbq/slime",
    }
    for _, v in ipairs(speciesOrdering) do
        table.insert(config.speciesOrdering, v)
    end
	return config
end
