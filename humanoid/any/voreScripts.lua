
local Default = {
	states = {
		default = {},
	}
}
setmetatable(Default, _Transformation)
for k, v in pairs(Default.states) do
	setmetatable(v, _State)
end
Transformations.default = Default
Default.__index = Default

function Default:init()
end
function Default:update(dt)
end
function Default:uninit()
end

-- default state scripts
local default = Default.states.default
function default:init()
end
function default:update(dt)
end
function default:uninit()
end

function default.tryVore(name, action, target, ...)
	return sbq.tryVore(target, action.location, action.throughput)
end
function default.tryLetout(name, action, target, ...)
	return sbq.tryLetout(target, action.throughput)
end
