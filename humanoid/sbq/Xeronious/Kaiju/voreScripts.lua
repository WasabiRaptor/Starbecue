
local Kaiju = {
	states = {
		default = {},
	},
	locations = {}
}
setmetatable(Kaiju, Species.default)
for k, v in pairs(Kaiju.states) do
	setmetatable(v, Species.default.states[k] or _State)
end
for k, v in pairs(Kaiju.locations) do
	setmetatable(v, Species.default.locations[k] or _Location)
end

Species.Kaiju = Kaiju
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
