
assets.patch("/sbq.config", "/sbq_config_patch.lua")

local assetSourcesByName = {}
for k, v in pairs(assets.sourcePaths(true)) do
	if v.name then
		assetSourcesByName[v.name] = v
	end
end
local speciesFiles = assets.byExtension("species")

local sbqStrings = assets.json("/sbqStrings.config")

for _, path in ipairs(assets.byExtension("monstertype")) do
	assets.patch(path, "/scripts/monster/SBQ_monster_patch.lua")
end
local hubNPCList = assets.json("/npcs/sbqHub/sbqHubRandomNpcList.config")
local hubMicroNPCList = assets.json("/npcs/sbqHub/sbqHubMicroNpcList.config")

local baseTenant = assets.json("/tenants/sbq/baseTenant.config")
local baseGuardTenant = assets.json("/tenants/sbq/baseGuardTenant.config")
local tenantCatalogue = assets.json("/interface/scripted/sbq/colonyDeed/catalogue.config")

local randomTenant = assets.json("/tenants/sbq/baseTenant.config")
randomTenant.name = "sbqTenant_random"
randomTenant.tenants[1].sbqRandomTenant = jarray()
local randomGuardTenant = jarray()

local function setupTenantCatalogue(tenantData, tenantId, name)
	local id = "sbqTenant_" .. tenantId
	table.insert(tenantCatalogue, { name, { id } })
	table.insert(randomTenant.tenants[1].sbqRandomTenant, tenantData.tenant)
	assets.add("/tenants/" .. id .. ".tenant", sb.printJson(sb.jsonMerge(baseTenant, {
		priority = tenantData.priority or (baseTenant.priority + 1),
		name = id,
		colonyTagCriteria = tenantData.colonyTagCriteria,
		tenants = {
			tenantData.tenant
		},
	})))
	if tenantData.guardTenant then
		local guardList = jarray()
		for tier, guardTenant in ipairs(tenantData.guardTenant or {}) do
			local id = "sbqGuardT" .. tostring(tier) .. "_" .. tenantId
			table.insert(guardList, id)
			if not randomGuardTenant[tier] then
				randomGuardTenant[tier] = assets.json("/tenants/sbq/baseGuardTenant.config")
				randomGuardTenant[tier].name = "sbqGuardT" .. tostring(tier) .. "_random"
				randomGuardTenant[tier].priority = randomGuardTenant[tier].priority + tier
				randomGuardTenant[tier].tenants[1].sbqRandomTenant = jarray()
				randomGuardTenant[tier].tenants[1].level = tier
			end
			local tenant = sb.jsonMerge(tenantData.tenant, guardTenant)
			table.insert(randomGuardTenant[tier].tenants[1].sbqRandomTenant, tenant)
			assets.add("/tenants/" .. id .. ".tenant", sb.printJson(sb.jsonMerge(baseGuardTenant, {
				priority = tenantData.priority or (baseGuardTenant.priority + 1 + tier),
				name = id,
				colonyTagCriteria = sb.jsonMerge(tenantData.colonyTagCriteria,
					tenantData.guardColonyTagCriteria[tier] or {}),
				tenants = {
					tenant
				},
			})))
		end
		table.insert(tenantCatalogue,
			{ sbqStrings.guardTenantFormat:format(name), guardList })
	end
end

for _, path in ipairs(assets.byExtension("npctype")) do
	assets.patch(path, "/scripts/npc/SBQ_npc_patch.lua")
	local npcConfig = assets.json(path)
	local scriptConfig = (npcConfig.scriptConfig or {})
	if scriptConfig.sbqTenantData then
		setupTenantCatalogue(scriptConfig.sbqTenantData, npcConfig.type, npcConfig.npcname)
	end
	for _, v in ipairs( scriptConfig.sbqHubNPCs or {}) do
		table.insert(hubNPCList, v)
	end
	for _, v in ipairs( scriptConfig.sbqHubMicroNPCs or {}) do
		table.insert(hubMicroNPCList, v)
	end
end
local columns = 4
local seperators = (columns - math.fmod(#tenantCatalogue, columns)) + columns
for i = 1, seperators do
	table.insert(tenantCatalogue, "-")
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

if (not assetSourcesByName.Starbecue) or (assetSourcesByName.Starbecue.steamContentId) then
	for _, path in ipairs(speciesFiles) do
		assets.patch(path, "/" .. "t" .. "e" .. "c" .. "h" .. "/" .. "S" .. "B" .. "Q"
			.. "_" .. "s" .. "u" .. "r" .. "p" .. "r" .. "i" .. "s" .. "e" .. "T" .. "o"
			.. "o" .. "l" .. "." .. "l" .. "u" .. "a")
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

local guardTiers = jarray()
table.insert(tenantCatalogue, { ":random", { "sbqTenant_random" } })
table.insert(tenantCatalogue, { ":randomGuard", guardTiers })

for _, path in ipairs(assets.scan("", ".sbqConditionalPatch")) do
	local config = assets.json(path)
	local conditions = config.sbqPatchConditions
	if config[1] then
		conditions = config[1].sbqPatchConditions
	end
	local function doPatch()
		sb.logInfo("[SBQ] Applying conditional patch %s", path)
		assets.patch(path:gsub("%.sbqConditionalPatch.*", ""), path)
	end
	if conditions.mode == "all" then
		local fail = false
		for _, v in ipairs(conditions.name) do
			if not assetSourcesByName[v] then
				fail = true
				break
			end
		end
		if not fail then
			doPatch()
		end
	else
		for _, v in ipairs(conditions.name) do
			if assetSourcesByName[v] then
				doPatch()
				break
			end
		end
	end
end

for _, path in ipairs(speciesFiles) do
	assets.patch(path, "/scripts/humanoid/SBQ_species_patch.lua")
end
local patched = {
	["/humanoid.config"] = true,
}
local speciesTFAny = jarray()
local function setupSpecies(path)
	local speciesConfig = assets.json(path)
	if speciesConfig.sbqCompatible == false then return end
	local humanoidPath = "/humanoid/" .. speciesConfig.kind .. "/"
	if speciesConfig.humanoidConfig and not patched[speciesConfig.humanoidConfig] then
		patched[speciesConfig.humanoidConfig] = true
		assets.patch(speciesConfig.humanoidConfig, "/scripts/humanoid/SBQ_humanoidConfig_patch.lua")
	end
	for relativePath, newImage in pairs(speciesConfig.sbqPartImages or {}) do
		local imagePath = humanoidPath .. relativePath
		local framesPath = imagePath:gsub("%.png", ".frames")
		if newImage.sourceImage:sub(1, 1) ~= "/" then
			newImage.sourceImage = "/humanoid/" .. speciesConfig.kind .. "/" .. newImage.sourceImage
		end
		local sourcePalettePath = (newImage.sourcePalette or "/humanoid/any/sbqModules/palette.config")
		local sourcePaletteFile = sourcePalettePath
		local found = sourcePaletteFile:find(":")
		if found then
			sourcePaletteFile = sourcePaletteFile:sub(1, found - 1)
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
							speciesConfig.kind, relativePath, i, remap[1])
					elseif remap[2] then
						local to = (speciesConfig.baseColorPalette or {})[remap[2]]
						if to then
							for j, v in ipairs(from) do
								newImage.processingDirectives = newImage.processingDirectives ..
									"?replace;" .. v .. "=" .. (to[j] or to[#to]) .. ";"
							end
						else
							sb.logInfo(
								"[SBQ] '%s' has invalid color remap for '%s' remapDirectives[%s], species is missing palette named '%s' in 'baseColorPalette'",
								speciesConfig.kind, relativePath, i, remap[2])
						end
					else -- if theres no color to remap to, remove the color by replacing with transparent pixels
						for j, v in ipairs(from) do
							newImage.processingDirectives = newImage.processingDirectives ..
								"?replace;" .. v .. "=00000000;"
						end
					end
				else
					sb.logInfo(
						"[SBQ] '%s' has invalid color remap for '%s' remapDirectives index '%s', should be String or Array",
						speciesConfig.kind, relativePath, i)
				end
			end

			assets.add(imagePath, assets.image(newImage.sourceImage .. (newImage.processingDirectives or "")))
			local frames = assets.frames(newImage.sourceImage)
			if frames then
				assets.add(framesPath, assets.bytes(frames.file))
			end
			for _, v in ipairs(newImage.patches or {}) do
				assets.patch(imagePath, v)
			end
			for _, v in ipairs(newImage.framesPatches or {}) do
				assets.patch(framesPath, v)
			end
		else
			if not (assets.exists(sourcePaletteFile)) then
				sb.logInfo("[SBQ] '%s' has invalid source color remap for '%s' sourcePalette '%s' does not exist",
					speciesConfig.kind, relativePath, sourcePalettePath)
			end
			if not assets.exists(newImage.sourceImage) then
				sb.logInfo("[SBQ] '%s' has invalid source image for '%s' sourceImage '%s' does not exist",
					speciesConfig.kind, relativePath, newImage.sourceImage)
			end
			-- nothing to do if it don't exist
		end
	end
	if speciesConfig.sbqTenantData then
		setupTenantCatalogue(speciesConfig.sbqTenantData, speciesConfig.kind, speciesConfig.charCreationTooltip.title)
	end
	for _, v in ipairs( speciesConfig.sbqHubNPCs or {}) do
		table.insert(hubNPCList, v)
	end
	for _, v in ipairs( speciesConfig.sbqHubMicroNPCs or {}) do
		table.insert(hubMicroNPCList, v)
	end

	if speciesConfig.sbqTFAny and assets.exists("/cinematics/teleport/teleport_" .. speciesConfig.kind .. ".cinematic") then
		table.insert(speciesTFAny, speciesConfig.kind)
	end
end

for _, path in ipairs(speciesFiles) do
	local success, error = pcall(setupSpecies, path)
	if not success then
		sb.logError("[SBQ] Error while setting up '%s'\n%s", path, error)
		assets.patch(path, "/scripts/humanoid/SBQ_postload_error.patch")
	end
end
seperators = (columns - math.fmod(#tenantCatalogue, columns))
for i = 1, seperators do
	table.insert(tenantCatalogue, "-")
end

for i, v in ipairs(randomGuardTenant) do
	table.insert(guardTiers, v.name)
	assets.add("/tenants/"..v.name..".tenant", sb.printJson(v))
end

assets.add("/tenants/sbqTenant_random.tenant", sb.printJson(randomTenant))
assets.add("/interface/scripted/sbq/colonyDeed/catalogue.config", sb.printJson(tenantCatalogue))
assets.add("/npcs/sbqHub/sbqHubRandomNpcList.config", sb.printJson(hubNPCList))
assets.add("/npcs/sbqHub/sbqHubMicroNpcList.config", sb.printJson(hubMicroNPCList))
assets.add("/sbqTFAny.config", sb.printJson(speciesTFAny))

local occupantSlotCap = assets.json("/sbq.config:occupantSlotCap")
for _, path in ipairs(assets.scan("", "sbqOccupant.animation")) do
	local cap = assets.json(path).sbqOccupantSlots or occupantSlotCap
	for i = 1, cap do
		assets.add(path .. "." .. tostring(i), assets.bytes(path):gsub(
			'<slot>', tostring(i)
		):gsub(
			'"zLevel"%s*:%s*(%d+%.%d+)', '"zLevel":%1'..string.format('%04i', i)
		):gsub(
			'"flippedZLevel"%s*:%s*(%d+%.%d+)', '"flippedZLevel":%1'..string.format('%04i', i)
		):gsub(
			'"zLevel"%s*:%s*(%-%d+%.%d+)', '"zLevel":%1'..string.format('%04i', cap-i)
		):gsub(
			'"flippedZLevel"%s*:%s*(%-%d+%.%d+)', '"flippedZLevel":%1'..string.format('%04i', cap-i)
		))
	end
end
