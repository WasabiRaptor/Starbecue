
local Slime = {
	states = {
		default = {},
	},
	locations = {}
}
setmetatable(Slime, Species.default)
for k, v in pairs(Slime.states) do
	setmetatable(v, Species.default.states[k] or _State)
end
for k, v in pairs(Slime.locations) do
	setmetatable(v, Species.default.locations[k] or _Location)
end

Species.Slime = Slime
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
