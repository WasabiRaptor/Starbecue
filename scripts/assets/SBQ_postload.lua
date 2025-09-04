
assets.patch("/sbq.config", "/sbq_config_patch.lua")

for _, path in ipairs(assets.byExtension("monstertype")) do
	assets.patch(path, "/scripts/monster/SBQ_monster_patch.lua")
end

for _, path in ipairs(assets.byExtension("npctype")) do
	assets.patch(path, "/scripts/npc/SBQ_npc_patch.lua")
end

local armorLists = assets.json("/scripts/assets/SBQ_amor.config")
for _, path in ipairs(assets.byExtension("legs")) do
	local armor = assets.json(path)
	if not armor.sbqCompatible then
		if not armorLists.legsWhitelist[armor.itemName] then
			assets.patch(path, "/scripts/assets/SBQ_armor_hideCrotch_patch.config")
		end
		if armorLists.chestBlacklist[armor.itemName] then
			assets.patch(path, "/scripts/assets/SBQ_armor_hideChest_patch.config")
		end

	end
end
for _, path in ipairs(assets.byExtension("chest")) do
	local armor = assets.json(path)
	if not armor.sbqCompatible then
		if not armorLists.chestWhitelist[armor.itemName] then
			assets.patch(path, "/scripts/assets/SBQ_armor_hideChest_patch.config")
		end
		if armorLists.legsBlacklist[armor.itemName] then
			assets.patch(path, "/scripts/assets/SBQ_armor_hideCrotch_patch.config")
		end
	end
end
for _, path in ipairs(assets.byExtension("head")) do
	local armor = assets.json(path)
	if not armor.sbqCompatible then
		if armorLists.legsBlacklist[armor.itemName] then
			assets.patch(path, "/scripts/assets/SBQ_armor_hideCrotch_patch.config")
		end
		if armorLists.chestBlacklist[armor.itemName] then
			assets.patch(path, "/scripts/assets/SBQ_armor_hideChest_patch.config")
		end
	end
end
for _, path in ipairs(assets.byExtension("back")) do
	local armor = assets.json(path)
	if not armor.sbqCompatible then
		if armorLists.legsBlacklist[armor.itemName] then
			assets.patch(path, "/scripts/assets/SBQ_armor_hideCrotch_patch.config")
		end
		if armorLists.chestBlacklist[armor.itemName] then
			assets.patch(path, "/scripts/assets/SBQ_armor_hideChest_patch.config")
		end
	end
end

local speciesFiles = assets.byExtension("species")
for _, path in ipairs(speciesFiles) do
    assets.patch(path, "/scripts/humanoid/SBQ_species_patch.lua")
end
for _, path in ipairs(speciesFiles) do
	local speciesConfig = assets.json(path)
	local humanoidPath = "/humanoid/" .. speciesConfig.kind .. "/"
	for imagePath, newImage in pairs(speciesConfig.sbqPartImages or {}) do
		if newImage.sourceImage:sub(1, 1) ~= "/" then
			newImage.sourceImage = "/humanoid/" .. speciesConfig.kind .. "/" .. newImage.sourceImage
		end
		local sourcePalettePath = (newImage.sourcePalette or "/humanoid/any/sbqModules/palette.config")
		local sourcePaletteFile = sourcePalettePath
		local found = sourcePaletteFile:find(":")
		if found then
			sourcePaletteFile = sourcePaletteFile:sub(1,found-1)
		end
		if assets.exists(sourcePaletteFile) and assets.exists(newImage.sourceImage) then
			newImage.processingDirectives = newImage.processingDirectives or ""
			local sourcePalette = assets.json(sourcePalettePath)
			for i, remap in ipairs(newImage.remapDirectives or {}) do
				if type(remap) == "string" then
					newImage.processingDirectives = newImage.processingDirectives .. remap
				elseif type(remap) == "table" and remap[1] then
					local from = sourcePalette[remap[1]]
					if not from then
						sb.logInfo(
							"[SBQ] '%s' has invalid color remap for '%s' remapDirectives[%s], missing palette in source named '%s'",
							speciesConfig.kind, imagePath, i, remap[1])
					elseif remap[2] then
						local to = speciesConfig.baseColorPalette[remap[2]]
						if to then
							for j, v in ipairs(from) do
								newImage.processingDirectives = newImage.processingDirectives .. "?replace;" .. v .. "=" .. (to[j] or to[#to]) .. ";"
							end
						else
							sb.logInfo(
								"[SBQ] '%s' has invalid color remap for '%s' remapDirectives[%s], species is missing palette named '%s' in 'baseColorPalette'",
								speciesConfig.kind, imagePath, i, remap[2])
						end
					else -- if theres no color to remap to, remove the color by replacing with transparent pixels
						for j, v in ipairs(from) do
							newImage.processingDirectives = newImage.processingDirectives .. "?replace;" .. v .. "=00000000;"
						end
					end
				else
					sb.logInfo(
						"[SBQ] '%s' has invalid color remap for '%s' remapDirectives index '%s', should be String or Array",
						speciesConfig.kind, imagePath, i)
				end
			end
			assets.add(humanoidPath .. imagePath, assets.image(newImage.sourceImage .. (newImage.processingDirectives or "")))
			assets.add(humanoidPath .. (imagePath:gsub("%.png", ".frames")), assets.bytes(assets.frames(newImage.sourceImage).file))
		else
			if not (assets.exists(sourcePaletteFile)) then
				sb.logInfo("[SBQ] '%s' has invalid source color remap for '%s' sourcePalette '%s' does not exist",
					speciesConfig.kind, imagePath, sourcePalettePath)
			end
			if not assets.exists(newImage.sourceImage) then
				sb.logInfo("[SBQ] '%s' has invalid source image for '%s' sourceImage '%s' does not exist",
					speciesConfig.kind, imagePath, newImage.sourceImage)
			end
			-- nothing to do if it don't exist
		end
	end
end



local occupantSlotCap = assets.json("/sbq.config:occpantSlotCap")
for _, path in ipairs(assets.scan("", "sbqOccupant.animation")) do
	local cap = assets.json(path).sbqOccupantSlots or occupantSlotCap
	for i = 1, cap do
		assets.add(path .. "." .. i, assets.bytes(path):gsub(
			'<slot>', tostring(i)
		):gsub(
			'"zLevel"%s*:%s*(%d+%.%d+)', '"zLevel":%1'..string.format('%04d', i)
		):gsub(
			'"flippedZLevel"%s*:%s*(%d+%.%d+)', '"flippedZLevel":%1'..string.format('%04d', i)
		):gsub(
			'"zLevel"%s*:%s*(%-%d+%.%d+)', '"zLevel":%1'..string.format('%04d', 20-i)
		):gsub(
			'"flippedZLevel"%s*:%s*(%-%d+%.%d+)', '"flippedZLevel":%1'..string.format('%04d', 20-i)
		))
	end
end
