
local Fray = {
	states = {
		default = {},
	},
	locations = {}
}
setmetatable(Fray, Species.default)
for k, v in pairs(Fray.states) do
	setmetatable(v, Species.default.states[k] or _State)
end
for k, v in pairs(Fray.locations) do
	setmetatable(v, Species.default.locations[k] or _Location)
end

Species.Fray = Fray
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
