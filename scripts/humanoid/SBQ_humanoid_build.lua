local old = {
	build = build or function() end
}

local function setPath(input, path, value)
	local i = input
	for j, v in ipairs(path) do
		if type(i[v]) == "nil" then
			if j == #path then
				i[v] = value
				return true
			else
				i[v] = {}
			end
		elseif type(i[v]) ~= "table" then
			return false
		end
		i = i[v]
	end
end

local function includeSBQModule(humanoidConfig, module)
	if not module then return end
	local merge = false
	if type(module) == "string" then
		table.insert(humanoidConfig.sbqConfig.includes, module)
		module = root.assetJson(module)
	else
		merge = true
	end
	for _, v in ipairs(module.includes or {}) do
		includeSBQModule(humanoidConfig, root.assetJson(v))
		table.insert(humanoidConfig.sbqConfig.includes, v)
	end
	for _, v in ipairs(module.scripts or {}) do
		table.insert(humanoidConfig.sbqConfig.scripts, v)
	end
	for _, v in ipairs(module.animations or {}) do
		if type(v) == "string" then
			table.insert(humanoidConfig.animation.includes, v)
		else
			humanoidConfig.animation = sb.jsonMerge(humanoidConfig.animation, v)
		end
	end
	for _, v in ipairs(module.cosmeticAnimations or {}) do
		for i = 1, 20 do
			table.insert(humanoidConfig.animation.includes, v .. "." .. i)
		end
	end
	if humanoidConfig.bodyFullbright then
		for _, v in ipairs(module.bodyFullbrightParts or {}) do
			setPath(humanoidConfig.animation, { "animatedParts", "parts", v, "properties", "fullbright" }, true)
		end
	end
	for _, v in ipairs(module.occupantAnimations or {}) do
		for i = 1, (humanoidConfig.sbqOccupantSlots or 0) do
			table.insert(humanoidConfig.animation.includes, v .. "." .. i)
		end
	end
	if merge then
		-- make sure not to overwrite these when we merge
		module.includes = nil
		module.scripts = nil
		humanoidConfig.sbqConfig = sb.jsonMerge(humanoidConfig.sbqConfig, module)
	end
end

local function getSBQBuildArguments(humanoidConfig)
	for _, v in ipairs({
		"sbqModules",
		"sbqConfig",
		"sbqIdentityAnimationCustom"
	}) do
		if not humanoidConfig[v] then
			humanoidConfig[v] = root.assetJson("/humanoid.config:" .. v)
		end
		if type(humanoidConfig[v]) == "string" then
			humanoidConfig[v] = root.assetJson(v)
		end
	end
end

function build(identity, humanoidParameters, humanoidConfig, npcHumanoidConfig)
	if humanoidParameters.sbqEnabled then
		humanoidConfig.useAnimation = true
	end
	humanoidConfig = old.build(identity, humanoidParameters, humanoidConfig, npcHumanoidConfig)
	if not (humanoidConfig.useAnimation and humanoidConfig.sbqEnabled and (type(humanoidConfig.animation) == "table")) then
		return humanoidConfig
	end
	local sbqConfig = root.assetJson("/sbq.config")
	getSBQBuildArguments(humanoidConfig)
	for k, v in pairs(identity) do
		if type(v) == "string" then
			if humanoidConfig.sbqIdentityAnimationCustom[k] then
				humanoidConfig.animation = sb.jsonMerge(humanoidConfig.animation,
					humanoidConfig.sbqIdentityAnimationCustom[k][v] or {})
			end
		end
	end

	humanoidConfig.loungePositions = humanoidConfig.loungePositions or {}

	humanoidConfig.sbqConfig.seatCount = humanoidConfig.sbqConfig.seatCount or humanoidConfig.sbqOccupantSlots or 0
	for i = 1, (humanoidConfig.sbqConfig.seatCount) do
		humanoidConfig.loungePositions["occupant" .. tostring(i)] = {
			part = "occupant" .. tostring(i),
			partAnchor = "loungeOffset",
			orientation = "stand",
			statusEffects = jarray(),
			dance = "sbqIdle",
			enabled = false,
			usePartZLevel = true,
			dismountable = false,
		}
	end

	local baseModule = humanoidConfig.sbqConfig
	humanoidConfig.sbqConfig = {
		includes = jarray(),
		scripts = jarray()
	}
	includeSBQModule(humanoidConfig, baseModule)
	for i, slot in ipairs(humanoidConfig.sbqModuleOrder or sbqConfig.moduleOrder or {}) do
		local modules = humanoidConfig.sbqModules[slot] or {}
		local selectedModule = humanoidParameters["sbqModule_" .. slot]
		if selectedModule and (selectedModule ~= "disable") then
			if modules[selectedModule] then
				includeSBQModule(humanoidConfig, modules[selectedModule])
			else
				includeSBQModule(humanoidConfig, modules.default)
			end
		end
	end

	return humanoidConfig
end
