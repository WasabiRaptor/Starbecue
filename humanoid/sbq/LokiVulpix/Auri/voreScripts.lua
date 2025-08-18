
local Auri = {
	states = {
		default = {},
	},
	locations = {}
}
setmetatable(Auri, sbq.SpeciesScripts.default)
for k, v in pairs(Auri.states) do
	setmetatable(v, sbq.SpeciesScripts.default.states[k] or sbq._State)
end
for k, v in pairs(Auri.locations) do
	setmetatable(v, sbq.SpeciesScripts.default.locations[k] or sbq._Location)
end

sbq.SpeciesScripts.Auri = Auri
Auri.__index = Auri

function Auri:init()
end
function Auri:update(dt)
	sbq.eyeTracking()
end
function Auri:uninit()
end

-- default state scripts
local default = Auri.states.default
function default:init()
end
function default:update(dt)
end
function default:uninit()
end
