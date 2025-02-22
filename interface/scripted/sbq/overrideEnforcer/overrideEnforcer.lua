local data = _ENV.metagui.inputData
if not data.owner then
	data.owner = player.uniqueId()
	world.sendEntityMessage(pane.sourceEntity(), "sbqSetOwner", player.uniqueId())
elseif (data.owner ~= player.uniqueId()) and not player.isAdmin() then
	sbq.playErrorSound()
	pane.dismiss()
	return
end

-- actually build and make the menu functional

local function setParameter(self)
    world.sendEntityMessage(pane.sourceEntity(), "sbqSetParameter", self.id, sb.parseJson(self.text))
end
_ENV.overrideSettings:setText(sb.printJson(data.overrideSettings or {}))
_ENV.overrideSettings_player:setText(sb.printJson(data.overrideSettings_player or {}))
_ENV.overrideSettings_npc:setText(sb.printJson(data.overrideSettings_npc or {}))
_ENV.overrideSettings_object:setText(sb.printJson(data.overrideSettings_object or {}))

_ENV.invalidSettings:setText(sb.printJson(data.invalidSettings or {}))
_ENV.invalidSettings_player:setText(sb.printJson(data.invalidSettings_player or {}))
_ENV.invalidSettings_npc:setText(sb.printJson(data.invalidSettings_npc or {}))
_ENV.invalidSettings_object:setText(sb.printJson(data.invalidSettings_object or {}))

_ENV.overrideSettings.onEnter = setParameter
_ENV.overrideSettings_player.onEnter = setParameter
_ENV.overrideSettings_npc.onEnter = setParameter
_ENV.overrideSettings_object.onEnter = setParameter

_ENV.invalidSettings.onEnter = setParameter
_ENV.invalidSettings_player.onEnter = setParameter
_ENV.invalidSettings_npc.onEnter = setParameter
_ENV.invalidSettings_object.onEnter = setParameter

function _ENV.breakObject:onClick()
	world.sendEntityMessage(pane.sourceEntity(), "sbqSmash")
end
