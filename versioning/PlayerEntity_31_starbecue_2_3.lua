require "/scripts/versioningutils.lua"

function update(diskStore)
	if diskStore.genericScriptStorage and diskStore.genericScriptStorage.starbecue and diskStore.statusController then
		diskStore.genericScriptStorage.starbecue.wr_speciesIdentities = diskStore.genericScriptStorage.starbecue.sbqSpeciesIdentities or diskStore.statusController.statusProperties.sbqSpeciesIdentities
		diskStore.genericScriptStorage.starbecue.sbqSpeciesIdentities = nil
		diskStore.statusController.statusProperties.sbqSpeciesIdentities = nil

		if diskStore.genericScriptStorage.starbecue.sbqOriginalSpecies then
			diskStore.genericScriptStorage.starbecue.wr_originalIdentity = (diskStore.genericScriptStorage.starbecue.sbqSpeciesIdentities or {})[diskStore.genericScriptStorage.starbecue.sbqOriginalSpecies]
		end
		diskStore.genericScriptStorage.starbecue.sbqOriginalSpecies = nil
		diskStore.genericScriptStorage.starbecue.sbqOriginalGender = nil
	end
	return diskStore
end
