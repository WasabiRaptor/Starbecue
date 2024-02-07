require("/scripts/SBQ_everything_primary.lua")
local old = {
	init = init,
	update = update
}
require("/scripts/SBQ_public_settings.lua")
function init()
	old.init()
	sbq.setupPublicSettings()
end
