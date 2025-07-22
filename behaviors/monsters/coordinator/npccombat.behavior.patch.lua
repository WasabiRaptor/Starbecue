function patch(config)
    local scripts = {
		"/stagehands/coordinator/npccombat.lua",
		"/stagehands/coordinator/SBQ_VoreNPC_Combat.lua"
    }
    for _, v in ipairs(scripts) do
        table.insert(config.scripts, v)
    end
	return config
end
