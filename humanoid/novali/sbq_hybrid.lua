

local _sbq_transformPlayer = sbq.transformPlayer
function sbq.transformPlayer(i)
	local data = sbq.occupant[i].progressBarData or {species = sbq.species, gender = sbq.settings.TFTG or "noChange"}
	local id = sbq.occupant[i].id
	sbq.addRPC(world.sendEntityMessage(id,"sbqGetIdentity"), function (overrideData)
		if root.speciesConfig("novali")
		and ((((data.species == "avali") or (data.species == "novali")) and ((overrideData.species == "novakid") or (overrideData.species == "novali")))
		or (((overrideData.species == "avali") or (overrideData.species == "novali")) and ((data.species == "novakid") or (data.species == "novali"))))
		then
			if overrideData.species == "avali" then
				data.species = "novali"
				data.facialHairType = "20"
				data.hairType = overrideData.hairType
			elseif overrideData.species == "novakid" then
				data.species = "novali"
				data.facialHairType = overrideData.facialHairType
				data.bodyDirectives = overrideData.bodyDirectives
                data.hairDirectives = overrideData.hairDirectives
				data.emoteDirectives = overrideData.emoteDirectives
                data.facialHairDirectives = overrideData.facialHairDirectives
				data.facialMaskDirectives = overrideData.facialMaskDirectives
			elseif overrideData.species == "novali" and data.species == "avali" then
				data.species = "avali"
				data.hairType = overrideData.hairType
			elseif overrideData.species == "novali" and data.species == "novakid" then
				data.species = "novakid"
				if overrideData.facialHairType ~= "20" then
					data.facialHairType = overrideData.facialHairType
				end
				data.bodyDirectives = overrideData.bodyDirectives
                data.hairDirectives = overrideData.hairDirectives
				data.emoteDirectives = overrideData.emoteDirectives
                data.facialHairDirectives = overrideData.facialHairDirectives
				data.facialMaskDirectives = overrideData.facialMaskDirectives
			end

			sbq.occupant[i].progressBarData = data
		end
		_sbq_transformPlayer(i)
	end)
end
