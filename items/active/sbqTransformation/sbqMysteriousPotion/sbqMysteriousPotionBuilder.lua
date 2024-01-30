local speciesFile

function build(directory, config, parameters, level, seed)
    local config = sb.jsonMerge(config, parameters or {})
	parameters = parameters or {}
	parameters.args = config.args

	if config.args and config.args[1] then
        local identity = config.args[1]
		if identity.species and (identity.species ~= "any") then
			speciesFile = root.speciesConfig(identity.species)
			if speciesFile then
                config.shortdescription = speciesFile.charCreationTooltip.title .. " Potion"
				parameters.potionPath = speciesFile.potionPath or parameters.potionPath
            end
			if speciesFile.baseColorMap then
				-- TODO make potions use the species colors
			end
        end
		if identity.name then
			config.shortdescription = parameters.name.." Potion"
		end
	end

	return config, parameters
end

function tableMatches(a, b)
	local b = b or {}
    for k, v in pairs(a or {}) do
	  if type(v) == "table"
	  and type(b[k]) == "table"
	  and not tableMatches(v, b[k]) then
		return false
	  end
	  if v ~= b[k] then
		return false
	  end
	end
	return true
end
