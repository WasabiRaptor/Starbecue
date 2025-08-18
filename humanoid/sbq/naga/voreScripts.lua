
local Naga = {
	states = {
		default = {},
	},
	locations = {}
}
setmetatable(Naga, sbq.SpeciesScripts.default)
for k, v in pairs(Naga.states) do
	setmetatable(v, sbq.SpeciesScripts.default.states[k] or sbq._State)
end
for k, v in pairs(Naga.locations) do
	setmetatable(v, sbq.SpeciesScripts.default.locations[k] or sbq._Location)
end

sbq.SpeciesScripts.Naga = Naga
Naga.__index = Naga

function Naga:init()
    local identity = sbq.humanoidIdentity()
	local hybridConfig = root.speciesConfig(identity.species)
	if identity.imagePath then
		local speciesConfig = root.speciesConfig(identity.imagePath)
		if speciesConfig then
			local path = "/humanoid/"..identity.imagePath.."/"
			status.setStatusProperty("ouchNoise", (identity.gender == "male" and speciesConfig.ouchNoises[1]) or speciesConfig.ouchNoises[2])
			world.sendEntityMessage(entity.id(), "sbqResetOuchNoise")
			local speciesAnimation = sb.jsonMerge(root.assetJson(speciesConfig.animationConfig or "/humanoid/any/humanoid.animation"), sbq.fetchConfigArray(speciesConfig.animationCustom, path))
            for k, v in pairs(speciesAnimation.globalTagDefaults) do
                if (not identity[k]) and (not speciesConfig.colorRemapGlobalTags[k]) then animator.setGlobalTag(k, v) end
            end
		end
	end
end
function Naga:update(dt)
end
function Naga:uninit()
end

-- default state scripts
local default = Naga.states.default
function default:init()
end
function default:update(dt)
end
function default:uninit()
end
