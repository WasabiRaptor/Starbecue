
local quadruped_big = {
	states = {
		default = {},
	},
	locations = {}
}
setmetatable(quadruped_big, sbq.SpeciesScripts.default)
for k, v in pairs(quadruped_big.states) do
	setmetatable(v, sbq.SpeciesScripts.default.states[k] or sbq._State)
end
for k, v in pairs(quadruped_big.locations) do
	setmetatable(v, sbq.SpeciesScripts.default.locations[k] or sbq._Location)
end

sbq.SpeciesScripts.Auri = quadruped_big
quadruped_big.__index = quadruped_big

function quadruped_big:init()
end
function quadruped_big:update(dt)
	sbq.eyeTracking()
end
function quadruped_big:uninit()
end

-- default state scripts
local default = quadruped_big.states.default
function default:init()
end
function default:update(dt)
end
function default:uninit()
end
