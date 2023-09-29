require("/scripts/util.lua")
require("/quests/scripts/generated/common.lua")

-- Same as escort.lua except for adding the "bring" objective

function onInit()
  self.questClient:setMessageHandler("entitiesDead", onEntitiesDead)
  self.questClient:setMessageHandler("entitiesSpawned", onEntitiesSpawned)

  -- Function to check when the target is within a short distance of the quest giver
  -- This apparently runs during script update, so make sure the script updateDelta isn't too low
  objective("bring"):setCompleteFn(function()
    return objective("find"):isComplete() and targetBrought()
  end)
end

function onEntitiesDead(_, _, group)
  if group ~= "targets" then return end
  quest.fail()
end

function onEntitiesSpawned(_, _, group, entityNames)
  if group == "targets" then
    assert(#entityNames == 1)

    setIndicators(entityNames)
    self.compass:setTarget("parameter", entityNames[1])
  end
end

function questInteract(entityId)
  if not quest.parameters().target then return end
  if world.entityUniqueId(entityId) ~= quest.parameters().target.uniqueId then return end

  notifyNpc("target", "foundEscort")
  objective("find"):complete()
  return true
end

function targetBrought()
  local brought = false
  -- We only have the uniqueId for the target and questGiver, so we have to use promises
  if not self.targetPromise then
    self.targetPromise = world.findUniqueEntity(quest.parameters().target.uniqueId)
  end
  if not self.questGiverPromise then
    self.questGiverPromise = world.findUniqueEntity(quest.parameters().questGiver.uniqueId)
  end

  -- TODO - Check if target is vored so we can require they be released for completion?

  if self.targetPromise:finished() and self.questGiverPromise:finished() then
    if self.targetPromise:succeeded() and self.questGiverPromise:succeeded() then
      -- The results of each should be a Vec2F
      local distance = world.magnitude(self.targetPromise:result(), self.questGiverPromise:result())
      local goalDistance = config.getParameter("goalDistance") or 10.0
      if distance < goalDistance then
        brought = true
      end
    end
    self.targetPromise = nil
    self.questGiverPromise = nil
  end

  return brought
end

function conditionsMet()
  return allObjectivesComplete()
end
