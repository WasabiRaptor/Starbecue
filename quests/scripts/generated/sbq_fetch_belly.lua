require("/quests/scripts/generated/common.lua")

function onInit()
  objective("fetch"):setCompleteFn(function()
    return hasItems()
  end)
end

function onUpdate(dt)
  -- Using object completion as a sort of state machine
  if not objective("enter"):isComplete() then
    checkEntered(dt)
  -- The complete function above will take care of the fetch objective
  elseif not objective("exit"):isComplete() then
    checkExited(dt)
  end
end

function checkEntered(dt)
  -- Must use a message to get the info we want
  if self.enterPromise == nil then
    self.enterPromise = world.sendEntityMessage(quest.parameters().questGiver.uniqueId, "sbqGetPreyEnabled")
  else
    if self.enterPromise:finished() then
      if self.enterPromise:succeeded() then
        local result = self.enterPromise:result()
        if type(result) == "table" then
          if type(result.preyList) == "table" and hasPlayerId(result.preyList) then
            -- Player made it inside the pred
            onEnter()
          end
        end
      end
      self.enterPromise = nil
    end
  end
end

function checkExited(dt)
  -- Must use a message to get the info we want
  if self.exitPromise == nil then
    self.exitPromise = world.sendEntityMessage(quest.parameters().questGiver.uniqueId, "sbqGetPreyEnabled")
  else
    if self.exitPromise:finished() then
      if self.exitPromise:succeeded() then
        local result = self.exitPromise:result()
        if type(result) == "table" then
          if type(result.preyList) == "table" and not hasPlayerId(result.preyList) then
            -- Player made it out of the pred
            onExit()
          end
        end
      end
      self.exitPromise = nil
    end
  end
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

function hasPlayerId(table)
  for _,id in ipairs(table) do
    if player.id() == id then return true end
  end
  return false
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
