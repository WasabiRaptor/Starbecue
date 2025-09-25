
local BigQuadruped = {
	states = {
		default = {},
	},
	locations = {}
}
setmetatable(BigQuadruped, sbq.SpeciesScripts.default)
for k, v in pairs(BigQuadruped.states) do
	setmetatable(v, sbq.SpeciesScripts.default.states[k] or sbq._State)
end
for k, v in pairs(BigQuadruped.locations) do
	setmetatable(v, sbq.SpeciesScripts.default.locations[k] or sbq._Location)
end

sbq.SpeciesScripts.Auri = BigQuadruped
BigQuadruped.__index = BigQuadruped

function BigQuadruped:init()
end
function BigQuadruped:update(dt)
	sbq.eyeTracking()
end
function BigQuadruped:uninit()
end

-- default state scripts
local default = BigQuadruped.states.default
function default:init()
end
function default:update(dt)
end
function default:uninit()
end
