function sbq.convertVictimAnims(path)
	sbq.logInfo(path)
	local victimAnims = root.assetJson(path)
	local newAnims = {}
	for k, anim in pairs(victimAnims) do
		local newAnim = {
			properties = {},
			frameProperties = {
				transforms = {},
				hidden = {},
				orientation = {},
				emote = {}
			}
		}

		local translate = {0,0}
		local scale = {1,1}
		local rotate = 0
		local hidden = 1
		local orientation
		local emote
		for i = 1, math.max(#(anim.xs or {}), #(anim.ys or {}), #(anim.x or {}), #(anim.y or {}), #(anim.r or {}), #(anim.visible or {}) ) do
			hidden = ((anim.visible or {})[i] or hidden)
			orientation = ((anim.sitpos or {})[i] or orientation)
			emote = ((anim.emote or {})[i] or emote)
			scale = {
				((anim.xs or {})[i] or scale[1]) * hidden,
				((anim.ys or {})[i] or scale[2]) * hidden,
			}
			translate = {
				(anim.x or {})[i] or translate[1],
				(anim.y or {})[i] or translate[2],
			}
			rotate = (anim.r or {})[i] or rotate
			newAnim.frameProperties.transforms[i] = {
				scale = scale,
				translate = translate,
				rotate = rotate
			}
			newAnim.frameProperties.hidden[i] = hidden == 0
			newAnim.frameProperties.orientation[i] = orientation
			newAnim.frameProperties.emote[i] = emote
		end
		newAnims[k] = newAnim
	end
	sbq.logInfo(newAnims, 4)
	return newAnims
end
