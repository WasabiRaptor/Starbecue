
local Default = {
	default = {}
}
Transformation.default = Default
Default.__index = Default
setmetatable(Default, _Transformation)

function Default.default:tryVore(action, target)
	Occupants.addOccupant(target, action.location)
end
