
function onGetResource(entityId, resource)
	if not self.memberResources[entityId] then return end
  local memberResource = self.memberResources[entityId]:get(resource)
  if memberResource ~= nil then
    return memberResource
  else
    return self.groupResources:get(resource)
  end
end
