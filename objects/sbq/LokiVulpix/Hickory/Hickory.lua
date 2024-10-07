require("/scripts/object/SBQ_vore_object.lua")
require("/humanoid/any/voreScripts.lua")
local Hickory = {
	states = {
		default = {},
	},
	locations = {}
}
setmetatable(Hickory, Species.default)
for k, v in pairs(Hickory.states) do
	setmetatable(v, Species.default.states[k] or _State)
end
for k, v in pairs(Hickory.locations) do
	setmetatable(v, Species.default.locations[k] or _Location)
end

Species.Hickory = Hickory
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
