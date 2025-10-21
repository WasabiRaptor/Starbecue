local worldOverrideSettings = world.getProperty("sbqOverrideSettings") or {}
local globalOverrideSettings = root.getConfigurationPath("sbq.overrideSettings") or {}

local worldInvalidSettings = world.getProperty("sbqInvalidSettings") or {}
local globalInvalidSettings = root.getConfigurationPath("sbq.invalidSettings") or {}
if not (player.isAdmin() or (player.id() == world.mainPlayer())) then
	_ENV.mainTabField.tabs.worldOverrides:setVisible(false)
end
_ENV.world_overrideSettings_any:setText(sb.printJson(worldOverrideSettings.any or {}))
_ENV.world_overrideSettings_player:setText(sb.printJson(worldOverrideSettings.player or {}))
_ENV.world_overrideSettings_npc:setText(sb.printJson(worldOverrideSettings.npc or {}))
_ENV.world_overrideSettings_monster:setText(sb.printJson(worldOverrideSettings.monster or {}))
_ENV.world_overrideSettings_object:setText(sb.printJson(worldOverrideSettings.object or {}))

_ENV.world_invalidSettings_any:setText(sb.printJson(worldInvalidSettings.any or {}))
_ENV.world_invalidSettings_player:setText(sb.printJson(worldInvalidSettings.player or {}))
_ENV.world_invalidSettings_npc:setText(sb.printJson(worldInvalidSettings.npc or {}))
_ENV.world_invalidSettings_monster:setText(sb.printJson(worldInvalidSettings.monster or {}))
_ENV.world_invalidSettings_object:setText(sb.printJson(worldInvalidSettings.object or {}))

local function setWorldOverrideSettings(self, entityType)
    if not (player.isAdmin() or (player.id() == world.mainPlayer())) then
		interface.queueMessage(sbq.getString(":adminOrHostRequired"))
		sbq.playErrorSound()
	end
	local success, parsed = pcall(sb.parseJson, self.text)
	if success and parsed then
        worldOverrideSettings[entityType] = parsed
		world.setProperty("sbqOverrideSettings", worldOverrideSettings)
	end
end
function _ENV.world_overrideSettings_any:onEnter()
	setWorldOverrideSettings(self,"any")
end
function _ENV.world_overrideSettings_player:onEnter()
	setWorldOverrideSettings(self,"player")
end
function _ENV.world_overrideSettings_npc:onEnter()
	setWorldOverrideSettings(self,"npc")
end
function _ENV.world_overrideSettings_monster:onEnter()
	setWorldOverrideSettings(self,"monster")
end
function _ENV.world_overrideSettings_object:onEnter()
	setWorldOverrideSettings(self,"object")
end

local function setWorldInvalidSettings(self, entityType)
    if not (player.isAdmin() or (player.id() == world.mainPlayer())) then
		interface.queueMessage(sbq.getString(":adminOrHostRequired"))
		sbq.playErrorSound()
	end

	local success, parsed = pcall(sb.parseJson, self.text)
	if success and parsed then
        worldInvalidSettings[entityType] = parsed
		world.setProperty("sbqInvalidSettings", worldInvalidSettings)
	end
end
function _ENV.world_invalidSettings_any:onEnter()
	setWorldInvalidSettings(self,"any")
end
function _ENV.world_invalidSettings_player:onEnter()
	setWorldInvalidSettings(self,"player")
end
function _ENV.world_invalidSettings_npc:onEnter()
	setWorldInvalidSettings(self,"npc")
end
function _ENV.world_invalidSettings_monster:onEnter()
	setWorldInvalidSettings(self,"monster")
end
function _ENV.world_invalidSettings_object:onEnter()
	setWorldInvalidSettings(self,"object")
end

_ENV.global_overrideSettings_any:setText(sb.printJson(globalOverrideSettings.any or {}))
_ENV.global_overrideSettings_player:setText(sb.printJson(globalOverrideSettings.player or {}))
_ENV.global_overrideSettings_npc:setText(sb.printJson(globalOverrideSettings.npc or {}))
_ENV.global_overrideSettings_monster:setText(sb.printJson(globalOverrideSettings.monster or {}))
_ENV.global_overrideSettings_object:setText(sb.printJson(globalOverrideSettings.object or {}))

_ENV.global_invalidSettings_any:setText(sb.printJson(globalInvalidSettings.any or {}))
_ENV.global_invalidSettings_player:setText(sb.printJson(globalInvalidSettings.player or {}))
_ENV.global_invalidSettings_npc:setText(sb.printJson(globalInvalidSettings.npc or {}))
_ENV.global_invalidSettings_monster:setText(sb.printJson(globalInvalidSettings.monster or {}))
_ENV.global_invalidSettings_object:setText(sb.printJson(globalInvalidSettings.object or {}))

local function setGlobalOverrideSettings(self, entityType)
	local success, parsed = pcall(sb.parseJson, self.text)
	if success and parsed then
        globalOverrideSettings[entityType] = parsed
		root.setConfigurationPath("sbq.overrideSettings."..entityType, parsed)
	end
end
function _ENV.global_overrideSettings_any:onEnter()
	setGlobalOverrideSettings(self,"any")
end
function _ENV.global_overrideSettings_player:onEnter()
	setGlobalOverrideSettings(self,"player")
end
function _ENV.global_overrideSettings_npc:onEnter()
	setGlobalOverrideSettings(self,"npc")
end
function _ENV.global_overrideSettings_monster:onEnter()
	setGlobalOverrideSettings(self,"monster")
end
function _ENV.global_overrideSettings_object:onEnter()
	setGlobalOverrideSettings(self,"object")
end

local function setGlobalInvalidSettings(self, entityType)
	local success, parsed = pcall(sb.parseJson, self.text)
	if success and parsed then
		root.setConfigurationPath("sbq.invalidSettings."..entityType, parsed)
	end
end
function _ENV.global_invalidSettings_any:onEnter()
	setGlobalInvalidSettings(self,"any")
end
function _ENV.global_invalidSettings_player:onEnter()
	setGlobalInvalidSettings(self,"player")
end
function _ENV.global_invalidSettings_npc:onEnter()
	setGlobalInvalidSettings(self,"npc")
end
function _ENV.global_invalidSettings_monster:onEnter()
	setGlobalInvalidSettings(self,"monster")
end
function _ENV.global_invalidSettings_object:onEnter()
	setGlobalInvalidSettings(self,"object")
end
