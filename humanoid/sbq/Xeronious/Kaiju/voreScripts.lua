
local Kaiju = {
	states = {
		default = {},
	},
	locations = {}
}
setmetatable(Kaiju, sbq.SpeciesScripts.default)
for k, v in pairs(Kaiju.states) do
	setmetatable(v, sbq.SpeciesScripts.default.states[k] or sbq._State)
end
for k, v in pairs(Kaiju.locations) do
	setmetatable(v, sbq.SpeciesScripts.default.locations[k] or sbq._Location)
end

sbq.SpeciesScripts.Kaiju = Kaiju
Kaiju.__index = Kaiju

function Kaiju:init()
end
function Kaiju:update(dt)
end
function Kaiju:uninit()
end

-- default state scripts
local default = Kaiju.states.default
function default:init()
end
function default:update(dt)
end
function default:uninit()
end
