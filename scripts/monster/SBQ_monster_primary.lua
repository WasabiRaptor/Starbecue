require("/scripts/actor/SBQ_actor_primary.lua")
local old = {
	init = init,
	update = update
}
require("/scripts/any/SBQ_public_settings.lua")
function init()
	old.init()
	sbq.setupPublicSettings()
end
