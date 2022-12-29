local _init = init or function() end
function init()
	local directives = config.getParameter("directives")
	if directives then
		animator.setGlobalTag("directives", directives)
	end
	_init()
end
