local old = {
    initAnimator = initAnimator or (function ()end),
	equipmentSlotUpdated = equipmentSlotUpdated or (function ()end)
}
require("/scripts/SBQ_check_settings.lua")

function equipmentSlotUpdated(slot, itemDescriptor)
    old.equipmentSlotUpdated(slot, itemDescriptor)
    slotFunc = sbq[slot.."Slot"] or function() end
	slotFunc(itemDescriptor)
end

function initAnimator()
	old.initAnimator()

	local defaultColorMap = root.speciesConfig("human").baseColorMap
    local speciesConfig = root.speciesConfig(humanoid.species())
	sbq.animOverrideSettings = sb.jsonMerge(speciesConfig.animOverrideDefaultSettings or {}, status.statusProperty("speciesAnimOverrideSettings") or {}, status.statusProperty("speciesAnimOverrideOverrideSettings") or {})
	for tag, remaps in pairs(speciesConfig.colorRemapGlobalTags or {}) do
		animator.setGlobalTag(tag, sbq.remapColor(remaps, defaultColorMap, speciesConfig.baseColorMap or defaultColorMap))
    end
    for part, tags in pairs(speciesConfig.colorRemapPartTags or {}) do
		for tag, remaps in pairs(tags or {}) do
			animator.setPartTag(part, tag, sbq.remapColor(remaps, defaultColorMap, speciesConfig.baseColorMap or defaultColorMap))
		end
    end
    sbq.chestCosmeticSlot(humanoid.getItemSlot("chestCosmetic"))
	sbq.legsCosmeticSlot(humanoid.getItemSlot("legsCosmetic"))
	sbq.headCosmeticSlot(humanoid.getItemSlot("headCosmetic"))
	sbq.backCosmeticSlot(humanoid.getItemSlot("backCosmetic"))
end

function sbq.chestSlot(itemDescriptor)
	if not humanoid.getItemSlot("chestCosmetic") then
		sbq.chestCosmeticSlot(itemDescriptor)
	end
end
function sbq.legsSlot(itemDescriptor)
	if not humanoid.getItemSlot("legsCosmetic") then
		sbq.legsCosmeticSlot(itemDescriptor)
	end
end
function sbq.headSlot(itemDescriptor)
	if not humanoid.getItemSlot("headCosmetic") then
		sbq.headCosmeticSlot(itemDescriptor)
	end
end
function sbq.backSlot(itemDescriptor)
	if not humanoid.getItemSlot("backCosmetic") then
		sbq.backCosmeticSlot(itemDescriptor)
	end
end

function sbq.chestCosmeticSlot(itemDescriptor)
	if not itemDescriptor then itemDescriptor = humanoid.getItemSlot("chest") end
    if itemDescriptor then
		local item = root.itemConfig(itemDescriptor)
	else
	end
end
function sbq.legsCosmeticSlot(itemDescriptor)
	if not itemDescriptor then itemDescriptor = humanoid.getItemSlot("legs") end
    if itemDescriptor then
		local item = root.itemConfig(itemDescriptor)
	else
	end
end
function sbq.headCosmeticSlot(itemDescriptor)
	if not itemDescriptor then itemDescriptor = humanoid.getItemSlot("head") end
    if itemDescriptor then
		local item = root.itemConfig(itemDescriptor)
	else
	end
end
function sbq.backCosmeticSlot(itemDescriptor)
	if not itemDescriptor then itemDescriptor = humanoid.getItemSlot("back") end
    if itemDescriptor then
		local item = root.itemConfig(itemDescriptor)
	else
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
	return ((directives ~= "?replace") and directives) or ""
end

-- this function in it's current state was made explicitly to add a missing color to familar's palettes
-- however, it should probably be repurposed to add a missing color to all palettes
function sbq.addDirectives()
	local directives = self.identity.bodyDirectives:lower()
	local found1, found2 = directives:find("00ffa1=")
	if found1 then
		local colorStartIndex = found2+1
		local colorEndIndex = #directives
		local found4 = directives:find(";", colorStartIndex)
		if found4 then
			local found5 = directives:find("?", colorStartIndex)
			if found5 and found4 > found5 then
				colorEndIndex = found5 -1
			else
				colorEndIndex = found4 -1
			end
		end

		local multiplyAmount = 0.75
		local color = directives:sub(colorStartIndex, colorEndIndex)
		local R = tonumber(color:sub(1,2),16)
		local G = tonumber(color:sub(3,4),16)
		local B = tonumber(color:sub(5,6),16)
		local A = ""
		if #color == 8 then
			A = color:sub(7,8)
		end
		local newReplaceColors = "?replace;00c77d="..string.format("%02x", math.floor(R * multiplyAmount))..string.format("%02x", math.floor(G * multiplyAmount))..string.format("%02x", math.floor(B * multiplyAmount))..A
		self.identity.bodyDirectives = self.identity.bodyDirectives..newReplaceColors
	end
end
