
local ZiellekDragon = {
	states = {
		default = {},
	},
	locations = {}
}
setmetatable(ZiellekDragon, Species.default)
for k, v in pairs(ZiellekDragon.states) do
	setmetatable(v, Species.default.states[k] or _State)
end
for k, v in pairs(ZiellekDragon.locations) do
	setmetatable(v, Species.default.locations[k] or _Location)
end

Species.ZiellekDragon = ZiellekDragon
ZiellekDragon.__index = ZiellekDragon

function ZiellekDragon:init()
end
function ZiellekDragon:update(dt)
end
function ZiellekDragon:uninit()
end

-- default state scripts
local default = ZiellekDragon.states.default
function default:init()
end
function default:update(dt)
end
function default:uninit()
end
