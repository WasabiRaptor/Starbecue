require("/scripts/object/SBQ_vore_object.lua")
require("/humanoid/any/sbqModules/base/voreScripts.lua")
local Sprink = {
	states = {
		default = {},
	},
	locations = {}
}
setmetatable(Sprink, sbq.SpeciesScripts.default)
for k, v in pairs(Sprink.states) do
	setmetatable(v, sbq.SpeciesScripts.default.states[k] or sbq._State)
end
for k, v in pairs(Sprink.locations) do
	setmetatable(v, sbq.SpeciesScripts.default.locations[k] or sbq._Location)
end

sbq.SpeciesScripts.Sprink = Sprink
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
