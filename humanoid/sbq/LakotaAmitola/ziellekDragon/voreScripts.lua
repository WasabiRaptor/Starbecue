
local ZiellekDragon = {
	states = {
		default = {},
	},
	locations = {}
}
setmetatable(ZiellekDragon, sbq.SpeciesScripts.default)
for k, v in pairs(ZiellekDragon.states) do
	setmetatable(v, sbq.SpeciesScripts.default.states[k] or sbq._State)
end
for k, v in pairs(ZiellekDragon.locations) do
	setmetatable(v, sbq.SpeciesScripts.default.locations[k] or sbq._Location)
end

sbq.SpeciesScripts.ZiellekDragon = ZiellekDragon
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
