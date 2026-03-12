require "/scripts/versioningutils.lua"

function update(diskStore)
	if diskStore.scriptStorage and diskStore.statusController then
		diskStore.scriptStorage.wr_speciesIdentities = diskStore.scriptStorage.sbqSpeciesIdentities or diskStore.statusController.statusProperties.sbqSpeciesIdentities
		diskStore.scriptStorage.sbqSpeciesIdentities = nil
		diskStore.statusController.statusProperties.sbqSpeciesIdentities = nil

		if diskStore.scriptStorage.sbqOriginalSpecies then
			diskStore.scriptStorage.wr_originalIdentity = (diskStore.scriptStorage.sbqSpeciesIdentities or {})[diskStore.scriptStorage.sbqOriginalSpecies]
		end
		diskStore.scriptStorage.sbqOriginalSpecies = nil
		diskStore.scriptStorage.sbqOriginalGender = nil
	end
	return diskStore
end
