local old = {
    initAnimator = initAnimator or (function ()end),
	equipmentSlotUpdated = equipmentSlotUpdated or (function ()end)
}
require("/scripts/any/SBQ_util.lua")

function equipmentSlotUpdated(slot, itemDescriptor)
    old.equipmentSlotUpdated(slot, itemDescriptor)
    local slotFunc = equipped[slot.."Slot"] or function(_) end
	slotFunc(itemDescriptor)
end

function initAnimator()
	old.initAnimator()
    --sb.logInfo(entity.entityType().." "..humanoid.getIdentity().name)
	sbq.refreshRemapTags()
	equipped.chestCosmeticSlot(humanoid.getItemSlot("chestCosmetic"))
	equipped.legsCosmeticSlot(humanoid.getItemSlot("legsCosmetic"))
	equipped.headCosmeticSlot(humanoid.getItemSlot("headCosmetic"))
    equipped.backCosmeticSlot(humanoid.getItemSlot("backCosmetic"))
	-- equipped.primary(humanoid.getItemSlot("primary"))
	-- equipped.alt(humanoid.getItemSlot("alt"))
end

function sbq.refreshRemapTags()
	local defaultColorMap = root.speciesConfig("human").baseColorMap
	local speciesConfig = root.speciesConfig(humanoid.species())
	for tag, remaps in pairs(speciesConfig.colorRemapGlobalTags or {}) do
		local sourceColorMap = sb.jsonQuery(speciesConfig, "colorRemapSources." .. tag)
		if sourceColorMap then sourceColorMap = root.speciesConfig(sourceColorMap).baseColorMap end
		local directives = sbq.remapColor(remaps, sourceColorMap or defaultColorMap, speciesConfig.baseColorMap or defaultColorMap)
		--sb.logInfo(tag.." "..directives)
		animator.setGlobalTag(tag, directives)
	end
	for part, tags in pairs(speciesConfig.colorRemapPartTags or {}) do
		for tag, remaps in pairs(tags or {}) do
			local sourceColorMap = sb.jsonQuery(speciesConfig, "colorRemapSources." .. part ..".".. tag) or sb.jsonQuery(speciesConfig, "colorRemapSources." .. tag)
			if sourceColorMap then sourceColorMap = root.speciesConfig(sourceColorMap).baseColorMap end
			local directives = sbq.remapColor(remaps, sourceColorMap or defaultColorMap, speciesConfig.baseColorMap or defaultColorMap)
			--sb.logInfo(tag.." "..directives)
			animator.setPartTag(part, tag, directives)
		end
	end
end

equipped = {}
function equipped.chestSlot(itemDescriptor)
	if not humanoid.getItemSlot("chestCosmetic") then
		equipped.chestCosmeticSlot(itemDescriptor)
	end
end
function equipped.legsSlot(itemDescriptor)
	if not humanoid.getItemSlot("legsCosmetic") then
		equipped.legsCosmeticSlot(itemDescriptor)
	end
end
function equipped.headSlot(itemDescriptor)
	if not humanoid.getItemSlot("headCosmetic") then
		equipped.headCosmeticSlot(itemDescriptor)
	end
end
function equipped.backSlot(itemDescriptor)
	if not humanoid.getItemSlot("backCosmetic") then
		equipped.backCosmeticSlot(itemDescriptor)
	end
end

function equipped.chestCosmeticSlot(itemDescriptor)
	if not itemDescriptor then itemDescriptor = humanoid.getItemSlot("chest") end
    if itemDescriptor then
		local item = root.itemConfig(itemDescriptor)
	else
	end
	if SpeciesScript then
		SpeciesScript:settingAnimations()
	end
end
function equipped.legsCosmeticSlot(itemDescriptor)
	if not itemDescriptor then itemDescriptor = humanoid.getItemSlot("legs") end
    if itemDescriptor then
		local item = root.itemConfig(itemDescriptor)
	else
	end
	if SpeciesScript then
		SpeciesScript:settingAnimations()
	end
end
function equipped.headCosmeticSlot(itemDescriptor)
	if not itemDescriptor then itemDescriptor = humanoid.getItemSlot("head") end
    if itemDescriptor then
		local item = root.itemConfig(itemDescriptor)
	else
	end
	if SpeciesScript then
		SpeciesScript:settingAnimations()
	end
end
function equipped.backCosmeticSlot(itemDescriptor)
	if not itemDescriptor then itemDescriptor = humanoid.getItemSlot("back") end
    if itemDescriptor then
		local item = root.itemConfig(itemDescriptor)
	else
	end
	if SpeciesScript then
		SpeciesScript:settingAnimations()
	end
end

function equipped.primary(itemDescriptor)
end
function equipped.alt(itemDescriptor)
end


function sbq.remapColor(remaps, fromMap, toMap)
	local directives = "?replace"
    for _, remap in ipairs(remaps or {}) do
        if remap[1] then
			local from = fromMap[remap[1]]
            local to = toMap[remap[2]]
            local check = remap[3]
            if from and to and sbq.tableMatches(check, sbq.settings, true) then
                for i, fromColor in ipairs(from) do
					local toColor = to[i] or to[#to]
					if (fromColor ~= toColor) then
						directives = directives..";"..fromColor.."="..toColor
					end
				end
            end
        elseif sbq.tableMatches(remap.check, sbq.settings, true) then
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
