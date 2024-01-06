local old = {
    initAnimator = initAnimator,
	equipmentSlotUpdated = equipmentSlotUpdated
}
require("/scripts/SBQ_check_settings.lua")

function equipmentSlotUpdated(slot, itemDescriptor)
	old.equipmentSlotUpdated(slot, itemDescriptor)
end


function initAnimator()
	local defaultColorMap = root.speciesConfig("human").baseColorMap
    local speciesConfig = root.speciesConfig(humanoid.species())

	sbq.animOverrideSettings = sb.jsonMerge(speciesConfig.animOverrideDefaultSettings or {}, status.statusProperty("speciesAnimOverrideSettings") or {}, status.statusProperty("speciesAnimOverrideOverrideSettings") or {})

    old.initAnimator()
	for tag, remaps in pairs(speciesConfig.colorRemapGlobalTags or {}) do
		animator.setGlobalTag(tag, sbq.remapColor(remaps, defaultColorMap, speciesConfig.baseColorMap or defaultColorMap))
    end
    for part, tags in pairs(speciesConfig.colorRemapPartTags or {}) do
		for tag, remaps in pairs(tags or {}) do
			animator.setPartTag(part, tag, sbq.remapColor(remaps, defaultColorMap, speciesConfig.baseColorMap or defaultColorMap))
		end
	end
end

function sbq.remapColor(remaps, fromMap, toMap)
	local directives = "?replace"
    for _, remap in ipairs(remaps or {}) do
        if remap[1] then
			local from = fromMap[remap[1]]
            local to = toMap[remap[2]]
            local check = remap[3]
            if sbq.checkSettings(check, sbq.animOverrideSettings) then
                for i, fromColor in ipairs(from) do
					local toColor = to[i] or to[#to]
					if (fromColor ~= toColor) then
						directives = directives..";"..fromColor.."="..toColor
					end
				end
            end
        elseif sbq.checkSettings(remap.check, sbq.animOverrideSettings) then
			for color, replace in pairs(remap or {}) do
				if type(replace) == "string" then
					directives = directives .. ";" .. color .. "=" .. replace
				end
            end
			directives = directives .. "?replace"
		end
    end
	sb.logInfo(((directives ~= "?replace") and directives) or "")
	return ((directives ~= "?replace") and directives) or ""
end
