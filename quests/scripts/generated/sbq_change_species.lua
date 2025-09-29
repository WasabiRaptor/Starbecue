require("/quests/scripts/generated/common.lua")

function onInit()
  -- Start with blank so we don't match anything until the polling starts
  storage.currentSpecies = ""
  -- With this function, the objective will dynamically complete/uncomplete as TFs happen
  objective("transform"):setCompleteFn(function()
    return storage.currentSpecies == goalSpecies()
  end)
end

function onUpdate(dt)
  -- Poll periodically. Make sure the script updateDelta isn't too low or this could get expensive
  pollSpecies()
end

function pollSpecies()
  -- Must use a message to get the info we want
  local eid = world.uniqueEntityId(quest.parameters().questGiver.uniqueId)
  if eid then
    storage.currentSpecies = world.entitySpecies(eid)
  end
end

-- With this, we can use the same script to handle more than one quest template
function goalSpecies()
  local paramName = config.getParameter("goalSpecies")
  return (quest.parameters()[paramName] or {}).name
end

function conditionsMet()
  return allObjectivesComplete()
end
