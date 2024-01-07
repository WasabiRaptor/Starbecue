local _init = init
function init()
	_init()
	world.sendEntityMessage(entity.id(), "cleanAnimOverrideScriptItems")
end
