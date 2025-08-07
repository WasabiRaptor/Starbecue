require("/quests/scripts/generated/common.lua")

function onInit()
  objective("fetch"):setCompleteFn(function()
    return hasItems()
  end)
end

function onUpdate(dt)
  -- Get quest giver's (pred's) entity id from their unique id
  local questGiverEntityId = world.uniqueEntityId(quest.parameters().questGiver.uniqueId)
  -- If quest giver can't be found, don't progress the quest
  if not questGiverEntityId then return end

  -- Using objective completion as a sort of state machine
  if not objective("enter"):isComplete() then
    if isPlayerInsideQuestGiver(questGiverEntityId) then
      onEnter()
    end
  -- The complete function above will take care of the fetch objective
  elseif not objective("exit"):isComplete() then
    if not isPlayerInsideQuestGiver(questGiverEntityId) then
      onExit()
    end
  end
end

function isPlayerInsideQuestGiver(questGiverEntityId)
  -- Return if Player is inside the quest giver
  --TODO Check specifically for the belly location
  return player.loungingIn() == questGiverEntityId
end

function onEnter()
  if objective("enter"):isComplete() then return end
  -- Give the player the items they find inside
  giveFetchedItems()
  -- Highlight the items if they get dropped
  setIndicators({config.getParameter("fetchList")})
  objective("enter"):complete()
end

function onExit()
  if objective("exit"):isComplete() then return end
  -- Indicators should auto-hide when the blue question mark appears
  objective("exit"):complete()
end

function giveFetchedItems()
  for _,item in pairs(fetchList()) do
    player.giveItem(item)
  end
end

function hasItems()
  for _,item in pairs(fetchList()) do
    if not player.hasItem(item) then
      return false
    end
  end
  return true
end

-- Vanilla fetch.lua uses this so the same script can handle multiple different quest templates.
function fetchList()
  local paramName = config.getParameter("fetchList")
  if not paramName then return true end
  return quest.parameters()[paramName].items or {}
end

function conditionsMet()
  return allObjectivesComplete()
end
