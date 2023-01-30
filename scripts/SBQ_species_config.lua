function sbq.getSpeciesConfig(species, settings)
	sbq.speciesConfig = root.assetJson("/humanoid/sbqData.config")

	local registry = root.assetJson("/humanoid/sbqDataRegistry.config")
	local path = registry[species] or "/humanoid/sbqData.config"
	if path:sub(1,1) ~= "/" then
		path = "/humanoid/"..species.."/"..path
	end
	local speciesConfig = root.assetJson(path)
	if type(speciesConfig.sbqData) == "table" then
		sbq.speciesConfig.sbqData = speciesConfig.sbqData
	end
	if type(speciesConfig.states) == "table" then
		sbq.speciesConfig.states = speciesConfig.states
	end

	sbq.speciesConfig.species = species
	local mergeConfigs = sbq.speciesConfig.sbqData.merge or {}
	local configs = { sbq.speciesConfig.sbqData }
	while type(mergeConfigs[#mergeConfigs]) == "string" do
		local insertPos = #mergeConfigs
		local newConfig = root.assetJson(mergeConfigs[#mergeConfigs]).sbqData
		for i = #(newConfig.merge or {}), 1, -1 do
			table.insert(mergeConfigs, insertPos, newConfig.merge[i])
		end

		table.insert(configs, 1, newConfig)

		table.remove(mergeConfigs, #mergeConfigs)
	end
	local scripts = {}
	local finalConfig = {}
	for i, config in ipairs(configs) do
		finalConfig = sb.jsonMerge(finalConfig, config)
		for j, script in ipairs(config.scripts or {}) do
			table.insert(scripts, script)
		end
	end

	for j, script in ipairs(sbq.speciesConfig.sbqData.scripts or {}) do
		table.insert(scripts, script)
	end
	sbq.speciesConfig.sbqData = finalConfig
	sbq.speciesConfig.sbqData.scripts = scripts

	local mergeConfigs = sbq.speciesConfig.states.merge or {}
	local configs = { sbq.speciesConfig.states }
	while type(mergeConfigs[#mergeConfigs]) == "string" do
		local insertPos = #mergeConfigs
		local newConfig = root.assetJson(mergeConfigs[#mergeConfigs]).states
		for i = #(newConfig.merge or {}), 1, -1 do
			table.insert(mergeConfigs, insertPos, newConfig.merge[i])
		end

		table.insert(configs, 1, newConfig)

		table.remove(mergeConfigs, #mergeConfigs)
	end
	local finalConfig = {}
	for i, config in ipairs(configs) do
		finalConfig = sb.jsonMerge(finalConfig, config)
	end
	sbq.speciesConfig.states = finalConfig

	for location, data in pairs(sbq.speciesConfig.sbqData.locations or {}) do
		local data = sb.jsonMerge(sbq.config.defaultLocationData[location] or {}, data)
		local infusedLocation
		local item = (settings or {})[location .. "InfusedItem"]
		if item and data.infusion then
			local infuseSpecies
			if ((((item.parameters or {}).npcArgs or {}).npcParam or {}).scriptConfig or {}).uniqueId then
				infuseSpecies = item.parameters.npcArgs.npcSpecies
			else
				infuseSpecies = (item.parameters or {}).species
			end
			if infuseSpecies then
				local sbqData = sbq.getSbqData(infuseSpecies) or {}
				infusedLocation = (sbqData.locations or {})[location]
				if infusedLocation then
					infusedLocation = sb.jsonMerge(sbq.config.defaultLocationData[location] or {}, infusedLocation)
					if infusedLocation.TF then
						if (not infusedLocation.TF.data) or (not infusedLocation.TF.data.species) then
							infusedLocation.TF.data = { species = infuseSpecies, playerSpeciesTF = true }
						end
					end
					-- this is to make sure that if you have used an infusion slot to get this modified locationData you can still get these options for *your* species
					for _, key in ipairs(sbq.config.nonInfusedData) do
						infusedLocation[key] = data[key]
					end
				end
			end
		end

		sbq.speciesConfig.sbqData.locations[location] = sb.jsonMerge(sbq.config.defaultLocationData[location] or {}, infusedLocation or data)
	end
end

function sbq.getSbqData(species)
	local registry = root.assetJson("/humanoid/sbqDataRegistry.config")
	local path = registry[species] or "/humanoid/sbqData.config"
	if path:sub(1,1) ~= "/" then
		path = "/humanoid/"..species.."/"..path
	end
	local speciesConfig = root.assetJson(path)
	if type(speciesConfig.sbqData) == "table" then
		local mergeConfigs = speciesConfig.sbqData.merge or {}
		local configs = { speciesConfig.sbqData }
		while type(mergeConfigs[#mergeConfigs]) == "string" do
			local insertPos = #mergeConfigs
			local newConfig = root.assetJson(mergeConfigs[#mergeConfigs]).sbqData
			for i = #(newConfig.merge or {}), 1, -1 do
				table.insert(mergeConfigs, insertPos, newConfig.merge[i])
			end

			table.insert(configs, 1, newConfig)

			table.remove(mergeConfigs, #mergeConfigs)
		end
		local finalConfig = {}
		for i, config in ipairs(configs) do
			finalConfig = sb.jsonMerge(finalConfig, config)
		end
		return finalConfig
	end
end
