
local Auri = {
	states = {
		default = {},
	}
}
setmetatable(Auri, Transformations.default)
for k, v in pairs(Auri.states) do
	setmetatable(v, _State)
end
Transformations.Auri = Auri
Auri.__index = Auri

function Auri:init()
end
function Auri:update(dt)
    local targetPos = sbq.distanceToLocal(sbq.targetPosition(), Transformation.state.eyesPosition or {0,0})

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
