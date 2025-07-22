
function patch(config)
    local scripts = {
		"/scripts/actions/world.lua",
		"/scripts/actions/entity.lua",
		"/scripts/actions/dialog.lua",
		"/scripts/actor/SBQ_behavior.lua"
    }
	for _, v in ipairs(scripts) do
		table.insert(config.scripts, v)
	end
	return config
end
