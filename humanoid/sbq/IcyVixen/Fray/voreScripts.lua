
local Fray = {
	states = {
		default = {},
	},
	locations = {}
}
setmetatable(Fray, sbq.SpeciesScripts.default)
for k, v in pairs(Fray.states) do
	setmetatable(v, sbq.SpeciesScripts.default.states[k] or sbq._State)
end
for k, v in pairs(Fray.locations) do
	setmetatable(v, sbq.SpeciesScripts.default.locations[k] or sbq._Location)
end

sbq.SpeciesScripts.Fray = Fray
Fray.__index = Fray

function Fray:init()
end
function Fray:update(dt)
	sbq.eyeTracking()
end
function Fray:uninit()
end

-- default state scripts
local default = Fray.states.default
function default:init()
end
function default:update(dt)
end
function default:uninit()
end
