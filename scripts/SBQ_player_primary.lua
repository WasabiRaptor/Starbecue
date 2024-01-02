require("/scripts/SBQ_everything_primary.lua")
require("/scripts/SBQ_humanoid.lua")
local old = {
	init = init,
	update = update
}
function init()
    old.init()
end
