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

local function includeSBQModule(humanoidConfig, module, infuseData)
	if not module then return end
	local merge = false
	local modulePath
	if type(module) == "string" then
		modulePath = module
		module = root.assetJson(module)
	else
		merge = true
	end
	for _, v in ipairs(module.includes or {}) do
		includeSBQModule(humanoidConfig, v)
	end
	if modulePath then
		table.insert(humanoidConfig.sbqConfig.includes, modulePath)
	end
	module.includes = nil
	for _, v in ipairs(module.scripts or {}) do
		table.insert(humanoidConfig.sbqConfig.scripts, v)
	end
	module.scripts = nil
	for _, v in ipairs(module.animations or {}) do
		if type(v) == "string" then
			table.insert(humanoidConfig.animation.includes, v)
		else
			humanoidConfig.animation = sb.jsonMerge(humanoidConfig.animation, v)
		end
	end
	module.animations = nil
	for _, v in ipairs(module.cosmeticAnimations or {}) do
		for i = 1, 20 do
			table.insert(humanoidConfig.animation.includes, v .. "." .. i)
		end
	end
	module.cosmeticAnimations = nil
	if humanoidConfig.bodyFullbright then
		for _, v in ipairs(module.bodyFullbrightParts or {}) do
			setPath(humanoidConfig.animation, { "animatedParts", "parts", v, "properties", "fullbright" }, true)
		end
	end
	module.bodyFullbrightParts = nil
	for _, v in ipairs(module.fullbrightParts or {}) do
		setPath(humanoidConfig.animation, { "animatedParts", "parts", v, "properties", "fullbright" }, true)
	end
	module.fullbrightParts = nil
	for _, v in ipairs(module.occupantAnimations or {}) do
		for i = 1, (humanoidConfig.sbqOccupantSlots or 0) do
			table.insert(humanoidConfig.animation.includes, v .. "." .. i)
		end
	end
	module.occupantAnimations = nil
	if module.modules then
		if type(module.modules) == "string" then
			module.modules = root.assetJson(module.modules)
		end
		for i, slot in ipairs(humanoidConfig.sbqModuleOrder or {}) do
			local modules = module.modules[slot]
			local selectedModule = humanoidConfig["sbqModule_" .. slot]
			if modules and selectedModule and (selectedModule ~= "disable") then
				includeSBQModule(humanoidConfig, modules[selectedModule] or modules.default, infuseData)
			end
		end
		module.modules = nil
	end

	if infuseData then
		for k, v in pairs(module.infuseTags) do
			humanoidConfig.animation.globalTagDefaults[k] = sb.replaceTags(v, {
				species = infuseData.species,
				humanoidPath = "/humanoid/" .. infuseData.species .. "/",
				gender = infuseData.gender,
				directives = infuseData.directives
			})
		end
		module.infuseTags = nil
		if infuseData.bodyFullbright then
			for _, v in ipairs(module.infusedBodyFullbrightParts or {}) do
				setPath(humanoidConfig.animation, { "animatedParts", "parts", v, "properties", "fullbright" }, true)
			end
		end
		module.infusedBodyFullbrightParts = nil
	end
	if module.infuseModules then
		if type(module.infuseModules) == "string" then
			module.infuseModules = root.assetJson(module.infuseModules)
		end
		for i, slot in ipairs(humanoidConfig.sbqModuleOrder or {}) do
			local newInfuseData = humanoidConfig["sbqInfused_" .. slot]
			if newInfuseData then
				local modules = module.infuseModules[slot]
				if modules then
					includeSBQModule(humanoidConfig, modules[newInfuseData.species] or modules.default, newInfuseData)
				end
			end
		end
		module.infuseModules = nil
	end
	if module.settingsConfig then
		humanoidConfig.sbqSettingsConfig = sb.jsonMerge(humanoidConfig.sbqSettingsConfig, module.settingsConfig)
		module.settingsConfig = nil
	end

	if merge then
		humanoidConfig.sbqConfig = sb.jsonMerge(humanoidConfig.sbqConfig, module)
	end
end


function build(identity, humanoidParameters, humanoidConfig, npcHumanoidConfig)
	if humanoidParameters.sbqEnabled and not humanoidConfig.sbqPostloadError then
		humanoidConfig.useAnimation = true
	end
	humanoidConfig = old.build(identity, humanoidParameters, humanoidConfig, npcHumanoidConfig)
	if (humanoidConfig.sbqCompatible == false) or humanoidConfig.sbqPostloadError or not (humanoidConfig.useAnimation and humanoidConfig.sbqEnabled and (type(humanoidConfig.animation) == "table")) then
		return humanoidConfig
	end
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
	humanoidConfig.sbqSettingsConfig = sb.jsonMerge(humanoidConfig.sbqSettingsConfig or {}, humanoidConfig.sbqInfuseSettings or {})
	return humanoidConfig
end
