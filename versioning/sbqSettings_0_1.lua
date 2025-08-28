require "/scripts/versioningutils.lua"

function update(storedSettings)
    -- there was a data leak in older versions with these, so just delete them when moving to the new version
    storedSettings.recentlyDigested = jarray()
    storedSettings.infuseSlots = {}

    -- convert parts being enabled to having selected the default
    if storedSettings.cock then
        storedSettings.cockSelect = "default"
    end
    if storedSettings.breasts then
        storedSettings.breastsSelect = "default"
    end
    if storedSettings.pussy then
        storedSettings.pussySelect = "default"
    end
    if storedSettings.balls then
        storedSettings.ballsSelect = "default"
    end

    storedSettings.cock = nil
    storedSettings.breasts = nil
    storedSettings.pussy = nil
    storedSettings.balls = nil

    storedSettings.maxScale = storedSettings.maximumScale
    storedSettings.minScale = storedSettings.minimumScale
    storedSettings.maximumScale = nil
    storedSettings.minimumScale = nil

    return storedSettings
end
