function getIdentity(eid, identity)
	local overrideData = status.statusProperty("speciesAnimOverrideData") or {}
	overrideData.gender = overrideData.gender or world.entityGender(eid)
	overrideData.species = overrideData.species or world.entitySpecies(eid)
	overrideData.identity = overrideData.identity or identity or {}
	overrideData.name = world.entityName(eid)
	overrideData.identity.gender = overrideData.gender

	local success, speciesFile = pcall(root.assetJson, ("/species/"..overrideData.species..".species"))
	if success then
		if type(speciesFile) == "table" then
			for i, data in ipairs(speciesFile.genders or {}) do
				if data.name == overrideData.gender then
					overrideData.identity.hairGroup = ((overrideData.identity.hairGroup ~= "") and overrideData.identity.hairGroup) or ((data.hairGroup ~= "") and data.hairGroup) or "hair"
					overrideData.identity.facialHairGroup = ((overrideData.identity.facialHairGroup ~= "") and overrideData.identity.facialHairGroup) or ((data.facialHairGroup ~= "") and data.facialHairGroup) or "facialHair"
					overrideData.identity.facialMaskGroup = ((overrideData.identity.facialMaskGroup ~= "") and overrideData.identity.facialMaskGroup) or ((data.facialMaskGroup ~= "") and data.facialMaskGroup) or "facialMask"
				end
			end
		end

		local portrait = world.entityPortrait(eid, "full")
		for _, part in ipairs(portrait) do
			local imageString = part.image
			--get personality values
			if not overrideData.identity.imagePath and not overrideData.species then
				local found1, found2 = imageString:find("humanoid/")
				if found1 then
					local found3, found4 = imageString:find("/"..status.statusProperty("animOverridesStoredGender") or world.entityGender(eid).."body")
					if found3 then
						overrideData.identity.imagePath = imageString:sub(found2+1, found3-1)
					end
				end
			else
				overrideData.identity.imagePath = overrideData.species
			end

			--get personality values
			if (not overrideData.identity.body) or (not overrideData.identity.bodyDirectives) or (not overrideData.identity.personalityIdle) then
				local found1, found2 = imageString:find("body.png:idle.")
				if found1 ~= nil then
					overrideData.identity.body = overrideData.identity.body or imageString:sub(found2+1, found2+1)
					overrideData.identity.personalityIdle = "idle."..overrideData.identity.body
					local found3 = imageString:find("?")
					local directives = imageString:sub(found3)
					overrideData.identity.bodyDirectives = overrideData.identity.bodyDirectives or directives
				end
			end
			if not overrideData.identity.emoteDirectives then
				local found1, found2 = imageString:find("emote.png")
				if found1 ~= nil then
					local found3 = imageString:find("?")
					local directives = imageString:sub(found3)
					overrideData.identity.emoteDirectives = overrideData.identity.emoteDirectives or directives
				end
			end
			if (not overrideData.identity.arm) or (not overrideData.identity.personalityArmIdle) then
				local found1, found2 = imageString:find("backarm.png:idle.")
				if found1 ~= nil then
					overrideData.identity.arm = imageString:sub(found2 + 1, found2 + 1)
					overrideData.identity.personalityArmIdle = "idle."..overrideData.identity.arm
				end
			end

			if (not overrideData.identity.hairType) or (not overrideData.identity.hairDirectives) then
				local found1, found2 = imageString:find("/"..(overrideData.identity.hairGroup or "hair").."/")
				if found1 ~= nil then
					local found3, found4 = imageString:find(".png:normal")
					overrideData.identity.hairType = overrideData.identity.hairType or imageString:sub(found2+1, found3-1)

					local found5, found6 = imageString:find("?addmask=")
					local directives = imageString:sub(found4+1, (found5 or 0)-1) -- this is really elegant haha

					overrideData.identity.hairDirectives = overrideData.identity.hairDirectives or directives
				end
			end

			if (not overrideData.identity.facialHairType) or not (overrideData.identity.facialHairDirectives) then
				local found1, found2 = imageString:find("/"..(overrideData.identity.facialHairGroup or "facialHair").."/")
				if found1 ~= nil then
					found3, found4 = imageString:find(".png:normal")
					overrideData.identity.facialHairType = overrideData.identity.facialHairType or imageString:sub(found2+1, found3-1)

					local found5, found6 = imageString:find("?addmask=")
					local directives = imageString:sub(found4+1, (found5 or 0)-1) -- this is really elegant haha
					overrideData.identity.facialHairDirectives = overrideData.identity.facialHairDirectives or directives
				end
			end

			if (not overrideData.identity.facialMaskType) or (not overrideData.identity.facialMaskDirectives) then
				local found1, found2 = imageString:find("/"..(overrideData.identity.facialMaskGroup or "facialMask").."/")
				if found1 ~= nil then
					found3, found4 = imageString:find(".png:normal")
					overrideData.identity.facialMaskType = overrideData.identity.facialMaskType imageString:sub(found2+1, found3-1)

					local found5, found6 = imageString:find("?addmask=")
					local directives = imageString:sub(found4+1, (found5 or 0)-1) -- this is really elegant haha
					overrideData.identity.facialMaskDirectives = overrideData.identity.facialMaskDirectives or directives
				end
			end
		end
	end
	return overrideData
end
