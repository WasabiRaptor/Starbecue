
local Auri = {
	states = {
		default = {},
    },
	locations = {}
}
setmetatable(Auri, Transformations.default)
for k, v in pairs(Auri.states) do
	setmetatable(v, Transformations.default.states[k] or _State)
end
for k, v in pairs(Auri.locations) do
	setmetatable(v, Transformations.default.locations[k] or _Location)
end

Transformations.Auri = Auri
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
