
local Slime = {
	states = {
		default = {},
	},
	locations = {}
}
setmetatable(Slime, sbq.SpeciesScripts.default)
for k, v in pairs(Slime.states) do
	setmetatable(v, sbq.SpeciesScripts.default.states[k] or sbq._State)
end
for k, v in pairs(Slime.locations) do
	setmetatable(v, sbq.SpeciesScripts.default.locations[k] or sbq._Location)
end

sbq.SpeciesScripts.Slime = Slime
Slime.__index = Slime

function Slime:init()
end
function Slime:update(dt)
end
function Slime:uninit()
end

-- default state scripts
local default = Slime.states.default
function default:init()
end
function default:update(dt)
end
function default:uninit()
end
