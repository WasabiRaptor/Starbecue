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
			local i = math.random(#data)
			local speciesConfig = root.speciesConfig(data[i].npc)
			local npcConfig = root.npcConfig(data[i].npcTypeName)
			local uuid = sbq.query(npcConfig, { "scriptConfig", "uniqueId" })
			if (not speciesConfig)
				or (not npcConfig)
				or (data[i].spawnOnce and world.getProperty(data[i].npc .. data[i].npcTypeName .. "Spawned"))
				or (uuid and world.loadUniqueEntity(uuid))
				or (not checkRequirements(data[i].checkRequirements or {}))
			then
				table.remove(data, i)
			else
				if data[i].bias or didBias then
					data = data[i]
					gotData = true
				else
					didBias = true
				end
			end
		end

		if not checkRequirements(config.getParameter("checkRequirements") or {}) then return stagehand.die() end

		local npc = data.npc or config.getParameter("npc")
		if type(npc) == "string" then
			if root.speciesConfig(npc) then
				world.spawnNpc(position, npc, data.npcTypeName or config.getParameter("npcTypeName"),
					data.npcLevel or config.getParameter("npcLevel") or world.threatLevel(),
					data.npcSeed or config.getParameter("npcSeed"),
					sb.jsonMerge(config.getParameter("npcParameters") or {}, data.npcParameters or {}))
				world.setProperty(npc .. (data.npcTypeName or config.getParameter("npcTypeName")) .. "Spawned", true)
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
