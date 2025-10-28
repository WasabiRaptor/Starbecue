---@diagnostic disable: undefined-field
sbq = {}
require "/scripts/any/SBQ_util.lua"

function update()
	local position = stagehand.position()
	if (world ~= nil)
		and (world.regionActive ~= nil)
		and world.regionActive({ position[1] - 1, position[2] - 1, position[1] + 1, position[2] + 1 })
	then

		local data = config.getParameter("randomSelection") or {}
		if type(data) == "string" then
			data = root.assetJson(data)
		end
		local gotData = false
		if data[1] == nil then
			gotData = true
		end
		local didBias = false
		while not gotData do
			if not data[1] then
				didBias = true
				data = config.getParameter("randomSelection") or {}
				if type(data) == "string" then
					data = root.assetJson(data)
				end
			end
			local i = math.random(#data)
			local speciesConfig = root.speciesConfig(data[i].species)
			local npcConfig = root.npcConfig(data[i].type)
			local uuid = sbq.query(npcConfig, { "scriptConfig", "uniqueId" })
			if (not speciesConfig)
				or (not npcConfig)
				or (data[i].spawnOnce and world.getProperty(data[i].species .. data[i].type .. "Spawned"))
				or (uuid and world.findUniqueEntity(uuid):result())
				or (not checkRequirements(data[i].checkRequirements or {}))
			then
				if data[i].bias then
					didBias = true
				end
				table.remove(data, i)
			else
				if data[i].bias or didBias then
					data = data[i]
					gotData = true
				end
			end
		end

		if not checkRequirements(config.getParameter("checkRequirements") or {}) then return stagehand.die() end

		local species = data.species or config.getParameter("species")
		if type(species) == "string" then
			if root.speciesConfig(species) then
				world.spawnNpc(position, species, data.type or config.getParameter("type"),
					data.level or config.getParameter("level") or world.threatLevel(),
					data.seed or config.getParameter("seed"),
					sb.jsonMerge(config.getParameter("overrides") or {}, data.overrides or {}))
				world.setProperty(species .. (data.type or config.getParameter("type")) .. "Spawned", true)
			end
		end
		stagehand.die()
	end
end

function checkRequirements(data)
	if data.checkItems then
		for i, item in ipairs(data.checkItems) do
			if not root.itemConfig(item) then return end
		end
	end
	if data.checkSpecies then
		for i, species in ipairs(data.checkSpecies) do
			if not root.speciesConfig(species) then return end
		end
	end
	if data.checkAssets then
		for i, path in ipairs(data.checkAssets) do
			if not root.assetOrigin(path) then return end
		end
	end
	return true
end
