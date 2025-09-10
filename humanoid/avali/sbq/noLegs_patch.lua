function patch(original)
	local image = original

	local crotch = image:subImage({ 59, 225 }, { 8, 5 })
	local walkBob  = assets.json("/humanoid.config:walkBob")
	local runBob  = assets.json("/humanoid.config:runBob")
	local swimBob = assets.json("/humanoid.config:swimBob")

	image:drawInto({ 274, 224 }, crotch) -- sit
	for i = 0, 7 do
		image:drawInto({ 59 + 43 * i, 182 + walkBob[i + 1] }, crotch) -- walk
		image:drawInto({ 59 + 43 * i, 140 + runBob[i + 1] }, crotch) -- run
	end
	for i = 0, 3 do
		image:drawInto({ 59 + 43 * i, 97 }, crotch) -- jump
		image:drawInto({ 232 + 43 * i, 97 }, crotch) -- fall
	end

	local swimCrotch = image:subImage({ 59, 11 }, { 8, 4 })
	for i = 0, 3 do
        image:drawInto({ 189 + 43 * i, 11 + swimBob[i + 1] }, swimCrotch) -- swim

	end

	return image
end
