---@diagnostic disable: undefined-global

message.setHandler("setBoobMask", function (_,_,booba)
	if booba then
		local part = replaceSpeciesGenderTags(self.speciesData.sbqBreastCover or "/humanoid/<species><reskin>/breasts/femaleBreastsCover.png")
		local success, notEmpty = pcall(root.nonEmptyRegion, (part))
		if success and notEmpty ~= nil then
			animator.setPartTag("genderBreastsCover", "partImage", part)
			self.parts["genderBreastsCover"] = part
		elseif self.speciesData.sbqBreastCoverRemap then
			local partname = "genderBreastsCover"
			local remapPart = self.speciesData.sbqBreastCoverRemap
			local part = replaceSpeciesGenderTags(remapPart.string or "/humanoid/<species><reskin>/breasts/femaleBreastsCover.png", remapPart.imagePath or remapPart.species, remapPart.reskin)
			local success2, baseColorMap = pcall(root.assetJson, "/species/" .. (remapPart.species or "human") .. ".species:baseColorMap")
			local colorRemap
			if success2 and baseColorMap ~= nil and remapPart.remapColors and self.speciesFile.baseColorMap then
				colorRemap = remapBaseColors(remapPart.remapColors, baseColorMap, self.speciesFile.baseColorMap)
			end
			animator.setPartTag(partname, "partImage", part)
			animator.setPartTag(partname, "colorRemap", colorRemap or "")
			self.parts[partname] = part
		end
		local part = replaceSpeciesGenderTags(self.speciesData.sbqBreastCoverMask or "/humanoid/<species><reskin>/breasts/mask/femalebody.png")
		local success, notEmpty = pcall(root.nonEmptyRegion, (part))
		if success and notEmpty ~= nil then
			animator.setGlobalTag("bodyMask1", part)
		end
	else
		animator.setPartTag("genderBreastsCover", "partImage", "")
		self.parts["genderBreastsCover"] = ""
		animator.setGlobalTag("bodyMask1", "/humanoid/animOverrideMasks/malebody.png")
	end
end)
