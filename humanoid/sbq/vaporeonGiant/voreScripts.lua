
local VaporeonGiant = {
	states = {
		default = {},
	},
	locations = {}
}
setmetatable(VaporeonGiant, sbq.SpeciesScripts.default)
for k, v in pairs(VaporeonGiant.states) do
	setmetatable(v, sbq.SpeciesScripts.default.states[k] or sbq._State)
end
for k, v in pairs(VaporeonGiant.locations) do
	setmetatable(v, sbq.SpeciesScripts.default.locations[k] or sbq._Location)
end

sbq.SpeciesScripts.VaporeonGiant = VaporeonGiant
VaporeonGiant.__index = VaporeonGiant

function VaporeonGiant:init()
end
function VaporeonGiant:update(dt)
end
function VaporeonGiant:uninit()
end

-- default state scripts
local default = VaporeonGiant.states.default
function default:init()
end
function default:update(dt)
end
function default:uninit()
end
