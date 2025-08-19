require "/scripts/versioningutils.lua"

function update(storedSettings)
    -- there was a data leak in older versions with these, so just delete them when moving to the new version
    storedSettings.recentlyDigested = jarray()
    storedSettings.infuseSlots = {}

    return storedSettings
end
