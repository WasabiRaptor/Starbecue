require "/scripts/versioningutils.lua"

local oldIdMap = {
	["sbq/flareon"] = "wr/flareon",
	["sbq/vaporeon"] = "wr/vaporeon",
	["sbq/meowscarada"] = "wr/meowscarada",
	["sbq/nickit_anthro"] = "wr/nickit_anthro"
}
function update(diskStore)
	if oldIdMap[diskStore.identity.species:lower()] then
		diskStore.identity.species = oldIdMap[diskStore.identity.species:lower()]
	end
	if diskStore.companions then
		fixFollowers(diskStore.companions.crew)
		fixFollowers(diskStore.companions.shipCrew)
		fixFollowers(diskStore.companions.followers)
	end
	return diskStore
end

function fixFollowers(companions)
	for i, companion in ipairs(companions or {}) do
		if oldIdMap[companion.config.species:lower()] then
			companion.config.species = oldIdMap[companion.config.species:lower()]
		end
		if oldIdMap[companion.config.parameters.identity.species:lower()] then
			companion.config.parameters.identity.species = oldIdMap[companion.config.parameters.identity.species:lower()]
		end
	end
end

function fixIdentities(identities)
	if not identities then return {} end
	local out = {}
	for k, v in pairs(identities) do
		v.species = oldIdMap[v.species:lower()] or v.species
		out[v.species] = v
	end
	return out
end
