function update(storedUpgrades)
    storedUpgrades.candyBonus = jarray()
    -- FU's fractional tiers gummed up the data at some point and caused things to be wonky, lets put things how they should be
    for k, v in pairs(storedUpgrades.candiesEaten or {}) do     -- iterate in pairs instead of ipairs because the fractional tiers may have caused the indexes to become saved as strings
        local level = math.max(math.floor(tonumber(k) or 1), 1) -- get the best integer tier we can from the key
        local value = math.floor(v or 0)
        local max = math.ceil(level / 2)
        for i = 1, level do -- make sure all the slots for preceding levels are filled with at least a 0
            storedUpgrades.candyBonus[i] = storedUpgrades.candyBonus[i] or 0
        end
        storedUpgrades.candyBonus[level] = math.max(storedUpgrades.candyBonus[level], math.min(value, max + 1)) -- make sure the new value is within the acceptable range
    end
    storedUpgrades.candiesEaten  = nil
    return storedUpgrades
end
