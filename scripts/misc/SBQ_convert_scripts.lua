function sbq.convertVictimAnims(path)
	local victimAnims = root.assetJson(path)
    local newAnims = {}
	for k, anim in pairs(victimAnims) do
        local newAnim = {
            properties = {},
            frameProperties = {
				transforms = {}
			}
		}

		local translate = {}
		local scale = {}
        local rotate

		for i = 1, math.max(#(anim.xs or {}), #(anim.ys or {}), #(anim.x or {}), #(anim.y or {}), #(anim.r or {}), #(anim.visible or {}) ) do
            scale = { ((anim.xs or {})[i] or scale[1] or 1) * ((anim.visible or {})[i] or 1),
                ((anim.ys or {})[i] or scale[2] or 1) * ((anim.visible or {})[i] or 1) }
            translate = {(anim.x or {})[i] or translate[1], (anim.y or {})[i] or translate[2] }
            rotate = (anim.r or {})[i] or rotate or 0
            newAnim.frameProperties.transforms[i] = {
                scale = scale,
                translate = translate,
				rotate = rotate
            }
        end
		newAnims[k] = newAnim
    end
    return newAnims
end

function sbq.createOccupantAnims()
    local anims = {}
    for i = 0, sbq.config.seatCount -1 do
        local occupantAnim = sbq.replaceConfigTags(
            root.fetchConfigArray(sbq.voreConfig.occupantAnimationConfig or "/humanoid/any/voreOccupant.animation"),
            {occupant = "occupant"..i}
        )
        anims = sb.jsonMerge(anims, occupantAnim)
    end
    sb.logInfo(sb.printJson(anims, 2, true))
end
