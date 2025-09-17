function patch(original)
	local image = original

	local crotch = image:subImage({ 17, 182 }, { 8, 4 })
	local walkBob  = assets.json("/humanoid.config:walkBob")
	local runBob  = assets.json("/humanoid.config:runBob")
	local swimBob = assets.json("/humanoid.config:swimBob")

	image:drawInto({ 232, 181 }, crotch) -- sit
	for i = 0, 7 do
		image:drawInto({ 17 + 43 * i, 139 + walkBob[i + 1] }, crotch) -- walk
		image:drawInto({ 17 + 43 * i, 97 + runBob[i + 1] }, crotch) -- run
	end
	for i = 0, 3 do
		image:drawInto({ 17 + 43 * i, 54 }, crotch) -- jump
		image:drawInto({ 189 + 43 * i, 54 }, crotch) -- fall
	end

	local swimCrotch = image:subImage({ 17, 11 }, { 8, 4 })
	for i = 0, 3 do
        image:drawInto({ 146 + 43 * i, 11 + swimBob[i + 1] }, swimCrotch) -- swim

	end

	return image
end
