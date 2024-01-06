---@diagnostic disable: undefined-field

function update()
	local position = stagehand.position()
	if (world ~= nil) and (world.regionActive ~= nil) and world.regionActive({position[1]-1,position[2]-1,position[1]+1,position[2]+1}) then

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
			if (data[i].spawnOnce and world.getProperty(data[i].npc..data[i].npcTypeName.."Spawned")) or (not checkRequirements(data[i].checkRequirements or {})) or (not root.speciesConfig(data[i].npc)) then
				table.remove(data,i)
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
				world.spawnNpc(position, npc, data.npcTypeName or config.getParameter("npcTypeName"), data.npcLevel or config.getParameter("npcLevel") or world.threatLevel(), data.npcSeed or config.getParameter("npcSeed"), data.npcParameters or config.getParameter("npcParameters"))
				world.setProperty( npc..(data.npcTypeName or config.getParameter("npcTypeName")).."Spawned", true)
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
	if data.checkMods then
		for i, mod in ipairs(data.checkMods) do
			if not root.modMetadata(mod) then return end
		end
    end
	if data.checkAssets then
		for i, path in ipairs(data.checkAssets) do
			if not root.assetExists(path) then return end
		end
	end
	return true
end
