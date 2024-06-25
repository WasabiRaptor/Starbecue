
local VaporeonGiant = {
	states = {
		default = {},
	},
	locations = {}
}
setmetatable(VaporeonGiant, Species.default)
for k, v in pairs(VaporeonGiant.states) do
	setmetatable(v, Species.default.states[k] or _State)
end
for k, v in pairs(VaporeonGiant.locations) do
	setmetatable(v, Species.default.locations[k] or _Location)
end

Species.VaporeonGiant = VaporeonGiant
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
