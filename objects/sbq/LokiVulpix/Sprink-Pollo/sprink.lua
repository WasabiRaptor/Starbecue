require("/scripts/object/SBQ_vore_object.lua")
require("/humanoid/any/sbqModules/base/voreScripts.lua")
local Sprink = {
	states = {
		default = {},
	},
	locations = {}
}
setmetatable(Sprink, Species.default)
for k, v in pairs(Sprink.states) do
	setmetatable(v, Species.default.states[k] or _State)
end
for k, v in pairs(Sprink.locations) do
	setmetatable(v, Species.default.locations[k] or _Location)
end

Species.Sprink = Sprink
Sprink.__index = Sprink

function Sprink:init()
end
function Sprink:update(dt)
end
function Sprink:uninit()
end

-- default state scripts
local default = Sprink.states.default
function default:init()
end
function default:update(dt)
end
function default:uninit()
end
