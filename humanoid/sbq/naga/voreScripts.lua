
local Naga = {
	states = {
		default = {},
	},
	locations = {}
}
setmetatable(Naga, Species.default)
for k, v in pairs(Naga.states) do
	setmetatable(v, Species.default.states[k] or _State)
end
for k, v in pairs(Naga.locations) do
	setmetatable(v, Species.default.locations[k] or _Location)
end

Species.Naga = Naga
Naga.__index = Naga

function Naga:init()
	local identity = humanoid.getIdentity()
    local speciesConfig = root.speciesConfig(identity.imagePath)
    if speciesConfig then
		local path = "/humanoid/"..identity.imagePath.."/"
		status.setStatusProperty("ouchNoise", (identity.gender == "male" and speciesConfig.ouchNoises[1]) or speciesConfig.ouchNoises[2])
		world.sendEntityMessage(entity.id(), "sbqResetOuchNoise")
		local speciesAnimation = sb.jsonMerge(root.assetJson(speciesConfig.animationConfig or "/humanoid/any/humanoid.animation"), root.fetchConfigArray(speciesConfig.animationCustom, path))
		for k, v in pairs(speciesAnimation.globalTagDefaults) do
			if not identity[k] then animator.setGlobalTag(k, v) end
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
