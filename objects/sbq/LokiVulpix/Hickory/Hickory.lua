require("/scripts/object/SBQ_vore_object.lua")
require("/humanoid/any/sbqModules/base/voreScripts.lua")
local Hickory = {
	states = {
		default = {},
	},
	locations = {}
}
setmetatable(Hickory, sbq.SpeciesScripts.default)
for k, v in pairs(Hickory.states) do
	setmetatable(v, sbq.SpeciesScripts.default.states[k] or sbq._State)
end
for k, v in pairs(Hickory.locations) do
	setmetatable(v, sbq.SpeciesScripts.default.locations[k] or sbq._Location)
end

sbq.SpeciesScripts.Hickory = Hickory
Hickory.__index = Hickory

function Hickory:init()
end
function Hickory:update(dt)
end
function Hickory:uninit()
end

-- default state scripts
local default = Hickory.states.default
function default:init()
end
function default:update(dt)
end
function default:uninit()
end
