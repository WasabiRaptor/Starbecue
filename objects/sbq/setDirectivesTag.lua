local _init = init or function() end
function init()
	local directives = config.getParameter("directives")
	if type(directives) == "string" then
		animator.setGlobalTag("directives", directives)
	elseif type(directives) == "table" then
		for tag, value in pairs(directives) do
			if type(value) == "string" then
				animator.setGlobalTag(tag, value)
			elseif type(value) == "table" then
				for tag2, val in pairs(value) do
					animator.setPartTag(tag, tag2, val)
				end
			end
		end
	end
	_init()
end
