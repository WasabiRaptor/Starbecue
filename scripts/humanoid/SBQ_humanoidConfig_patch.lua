function patch(config)
	for _, v in ipairs({
		"sbqModuleOrder",
		"sbqConfig",
		"sbqIdentityAnimationCustom",
		"sbqSettingsConfig"
	}) do
		if not config[v] then
			config[v] = assets.json("/humanoid.config:" .. v)
		end
		if type(config[v]) == "string" then
			config[v] = assets.json(config[v])
		end
	end
	if type(sb.jsonQuery(config, "sbqConfig.modules")) == "string" then
		config.sbqConfig.modules = assets.json(config.sbqConfig.modules)
	end
	return config
end
