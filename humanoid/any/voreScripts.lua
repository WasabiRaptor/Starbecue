
local Default = {
	states = {
		default = {},
	}
}
for k, v in pairs(Default.states) do
	setmetatable(v, _State)
end
Transformation.default = Default
Default.__index = Default
setmetatable(Default, _Transformation)


function Default:init()
end
function Default:update(dt)
end
function Default:uninit()
end

-- default state scripts
function Default.default:init()

end
function Default.default:update(dt)

end
function Default.default:uninit()

end

function Default.default.tryVore(name, action, target, ...)
	return sbq.tryVore(target, action.location, action.throughput)
end
function Default.default.tryLetout(name, action, target, ...)
	return sbq.tryLetout(target, action.throughput)
end
