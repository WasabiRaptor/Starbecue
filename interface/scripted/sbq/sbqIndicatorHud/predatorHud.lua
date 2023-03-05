
---@diagnostic disable:undefined-global


sbq = {
	sbqCurrentData = player.getProperty("sbqCurrentData") or {},
	refreshtime = 0,
	hudActions = root.assetJson("/interface/scripted/sbq/sbqIndicatorHud/hudActionScripts.config"),
	config = root.assetJson("/sbqGeneral.config"),
	overrideSettings = {},
	occupants = {
		total = 0
	}
}
function metagui.theme.drawFrame() -- maybe this could stop the background from drawing
end
local canvas = widget.bindCanvas(frame.backingWidget .. ".canvas")
canvas:clear()

speciesOverride = {}
function speciesOverride._species()
	return (status.statusProperty("speciesAnimOverrideData") or {}).species or speciesOverride.species()
end

function speciesOverride._gender()
	return (status.statusProperty("speciesAnimOverrideData") or {}).gender or speciesOverride.gender()
end
speciesOverride.species = player.species
player.species = speciesOverride._species

speciesOverride.gender = player.gender
player.gender = speciesOverride._gender

require("/scripts/SBQ_RPC_handling.lua")
require("/scripts/SBQ_species_config.lua")

function init()
	sbq.sbqSettings = player.getProperty("sbqSettings") or {}
	sbq.globalSettings = sb.jsonMerge(sbq.config.globalSettings, sbq.sbqSettings.global or {})

	if sbq.sbqCurrentData.species ~= nil then
		if sbq.sbqCurrentData.species == "sbqOccupantHolder" then
			sbq.getOccupantHolderData()
		else
			sbq.predatorConfig = root.assetJson("/vehicles/sbq/"..sbq.sbqCurrentData.species.."/"..sbq.sbqCurrentData.species..".vehicle").sbqData or {}
		end
		sbq.predatorSettings = sb.jsonMerge(sb.jsonMerge(sb.jsonMerge(sbq.config.defaultSettings, sbq.predatorConfig.defaultSettings or {}), sbq.sbqSettings[sbq.sbqCurrentData.species] or {}), sbq.globalSettings)
	else
		sbq.getOccupantHolderData()
		sbq.predatorSettings = sb.jsonMerge(sb.jsonMerge(sb.jsonMerge(sbq.config.defaultSettings, sbq.predatorConfig.defaultSettings or {}), sbq.sbqSettings.sbqOccupantHolder or {}), sbq.globalSettings)
	end
	sbq.overrideSettings = sbq.predatorConfig.overrideSettings or {}

	escapeValue:setText(tostring(sbq.globalSettings.escapeDifficulty or 0))

	if sbq.predatorConfig.listLocations then
		for i, location in ipairs(sbq.predatorConfig.listLocations or {}) do
			if sbq.predatorSettings.lastLocationSelect == location then
				sbq.locationSelectIndex = i
				break
			end
		end
		if not sbq.locationSelectIndex then
			sbq.locationSelectIndex = 1
			sbq.predatorSettings.lastLocationSelect = (sbq.predatorConfig.listLocations or {})[1]
		end
		if #sbq.predatorConfig.listLocations == 1 then
			prevLocation:setVisible(false)
			nextLocation:setVisible(false)
		end
		sbq.cycleLocation(0)
	else
		prevLocation:setVisible(false)
		nextLocation:setVisible(false)
		effectsPanel:setVisible(false)
	end
	impossibleEscape:setChecked(sbq.globalSettings.impossibleEscape)
	sbq.predUIeffectsPanel(sbq.predatorSettings.lastLocationSelect)
end

function sbq.getOccupantHolderData()
	sbq.getSpeciesConfig(player.species(), sbq.sbqSettings.global)
	sbq.predatorConfig = sbq.speciesConfig.sbqData
end


function sbq.listSlots()
	occupantSlots:clearChildren()
	local y = 217
	local slots = 7
	if sbq.sbqCurrentData.species == "sbqOccupantHolder" then
		slots = 8
	end
	for i = 1, sbq.occupants.total + 1 do
		if i <= slots then
			y = y - 25
			occupantSlots:addChild({ type = "image", noAutoCrop = true, position = {80,y}, file = "portraitSlot.png" })
		end
	end
end

sbq.listSlots()

function update()
	local dt = script.updateDt()
	sbq.checkRefresh(dt)
	sbq.checkRPCsFinished(dt)
	sbq.checkTimers(dt)
	sbq.updateBars()
end

function sbq.checkRefresh(dt)
	sbq.sbqSettings = player.getProperty("sbqSettings") or {}
	sbq.globalSettings = sb.jsonMerge(sbq.config.globalSettings, sbq.sbqSettings.global or {})

	sbq.sbqCurrentData = player.getProperty("sbqCurrentData") or {}
	if (sbq.sbqCurrentData.type == "driver") and type(sbq.sbqCurrentData.id)== "number" and world.entityExists(sbq.sbqCurrentData.id) then
		sbq.loopedMessage("checkRefresh", sbq.sbqCurrentData.id, "settingsMenuRefresh", {}, function (result)
			if result ~= nil then
				if result.isNested then
					pane.dismiss()
				end
				sbq.predatorSettings = result.settings
				sbq.occupants = result.occupants
				sbq.occupant = result.occupant
				sbq.powerMultiplier = result.powerMultiplier
				sbq.refreshtime = 0
				sbq.refreshList = result.refreshList or sbq.refreshList
				sbq.locked = result.locked

				sbq.refreshListData()
				sbq.readOccupantData()

				sbq.refreshed = true
			end
		end)
	else
		pane.dismiss()
	end
end

function sbq.refreshListData()
	if not sbq.refreshList then return end
	sbq.listSlots()
	occupantsArea:clearChildren()
	sbq.occupantList = {}
	sbq.listItems = {}
	sbq.refreshList = nil
end


sbq.occupantList = {}

function sbq.readOccupantData()
	if sbq.occupants.total > 0 then
		local y = 224
		local playerSpecies = (sbq.sbqCurrentData or {}).species

		if playerSpecies == "sbqOccupantHolder" then
			local maybeSpecies = player.species()
			if type(sbq.hudActions[maybeSpecies]) == "table" then
				playerSpecies = maybeSpecies
			end
		end

		for i, occupant in pairs(sbq.occupant) do
			local id = occupant.id
			if ((not ((i == "0") or (i == 0))) or sbq.sbqCurrentData.species == "sbqOccupantHolder") and (occupant ~= nil) and (type(id) == "number") and (world.entityExists( id )) then
				y = y - 25
				local species = occupant.species
				if type(sbq.occupantList[id]) ~= "table" then
					sbq.occupantList[id] = { layout = occupantsArea:addChild({ type = "layout", mode = "manual", position = {0,y}, size = {96,24}, children = {
						{ type = "image", noAutoCrop = true, position = {0,0}, file = "portrait.png"  },
						{ type = "canvas", id = id.."PortraitCanvas", position = {8,4}, size = {16,16} },
						{ type = "label", id = id.."Name", position = {32,8.5}, size = {48,10}, text = world.entityName( id ) },
						{ type = "canvas", id = id.."ProgressBar", position = {23,0}, size = {61,5} },
						{ type = "canvas", id = id .. "HealthBar", position = { 23, 19 }, size = { 61, 5 } },
						{ type = "image", noAutoCrop = true, position = {0,0}, file = "portraitCover.png"  },
						{ type = "iconButton", id = id.."ActionButton", noAutoCrop = true, position = {0,0}, image = "portrait.png?setcolor=FFFFFF?multiply=00000001"  }
					}})}
					sbq.occupantList[id].portrait = _ENV[id.."PortraitCanvas"]
					sbq.occupantList[id].healthbar = _ENV[id.."HealthBar"]
					sbq.occupantList[id].progressbar = _ENV[id.."ProgressBar"]
					sbq.occupantList[id].actionButton = _ENV[id.."ActionButton"]

					local occupantButton = sbq.occupantList[id].actionButton
					function occupantButton:onClick()
						local actionList = {}
						if world.entityType(id) == "npc" then
							table.insert(actionList, {"Interact", function() sbq.npcInteract(id, i) end})
						end
						for _, action in ipairs(sbq.hudActions.global) do
							if action.locations == nil or sbq.checkOccupantLocation(occupant.location, action.locations) then
								table.insert(actionList, {action.name, function() sbq[action.script](id, i) end})
							end
						end
						if type(sbq.hudActions[playerSpecies]) == "table" then
							for _, action in ipairs(sbq.hudActions[playerSpecies]) do
								if action.locations == nil or sbq.checkOccupantLocation(occupant.location, action.locations) then
									table.insert(actionList, {action.name, function() sbq[action.script](id, i) end})
								end
							end
						end
						metagui.contextMenu(actionList)
					end
				end

				if species == nil or species == "sbqOccupantHolder" then
					sbq.setPortrait(sbq.occupantList[id].portrait, world.entityPortrait( id, "bust" ), {8,2})
				else
					local skin = (occupant.smolPreyData.settings.skinNames or {}).head or "default"
					local directives = occupant.smolPreyData.settings.directives or ""
					sbq.setPortrait(sbq.occupantList[id].portrait, {{image = "/vehicles/sbq/"..species.."/skins/"..skin.."/icon.png"..directives, position = {0,0} }}, {8,8})
				end
			end
		end
	end
end

function sbq.checkOccupantLocation(occupantLocation, locations)
	for i, location in ipairs(locations) do
		if occupantLocation == location then return true end
	end
end

local HPPal = {"751900", "c61000", "f72929", "ffa5a5"}

local topBar = {
	empty = "/interface/scripted/sbq/barempty.png",
	full = "/interface/scripted/sbq/barfull.png",
	x = 0, y = 0, h = 5, w = 61,
	color = {"9e9e9e", "c4c4c4", "e4e4e4", "ffffff"}, -- defaults in barfull.png
}

local bottomBar = {
	empty = "/interface/scripted/sbq/barempty.png?flipy",
	full = "/interface/scripted/sbq/barfull.png?flipy",
	x = 0, y = 0, h = 5, w = 61,
	color = {"9e9e9e", "c4c4c4", "e4e4e4", "ffffff"}, -- defaults in barfull.png
}

function sbq.updateBars()
	if sbq.occupants.total > 0 and sbq.occupant ~= nil then
		for i, occupant in pairs(sbq.occupant) do
			if ((not ((i == "0") or (i == 0))) or sbq.sbqCurrentData.species == "sbqOccupantHolder") then
				local id = occupant.id
				if type(id) == "number" and world.entityExists(id) and sbq.occupantList[id] ~= nil then
					local health = world.entityHealth( id )
					sbq.progressBar( sbq.occupantList[id].healthbar, HPPal, health[1] / health[2], bottomBar )
					sbq.progressBar( sbq.occupantList[id].progressbar, occupant.progressBarColor, (occupant.progressBar or 0) / 100, topBar )
				end
			end
		end
	end
end

function sbq.replace(from, to)
	if to == nil or #to == 0 then return "" end
	local directive = "?replace;"
	for i, f in ipairs(from) do
		directive = directive .. f .. "=" .. to[i]:sub(1,6) .. ";"
	end
	return directive
end

function sbq.progressBar(canvas, color, percent, bar)
	local progressBar = widget.bindCanvas( canvas.backingWidget )
	progressBar:clear()

	local s = percent * bar.w
	if s < bar.w then
		progressBar:drawImageRect(
			bar.empty,
			{s, 0, bar.w, bar.h},
			{bar.x + s, bar.y, bar.x + bar.w, bar.y + bar.h}
		)
	end
	if s > 0 then
		progressBar:drawImageRect(
			bar.full .. sbq.replace(bar.color, color),
			{0, 0, s, bar.h},
			{bar.x, bar.y, bar.x + s, bar.y + bar.h}
		)
	end
end

function sbq.setPortrait( canvasName, data, offset )
	local canvas = widget.bindCanvas( canvasName.backingWidget )
	canvas:clear()
	for k,v in ipairs(data or {}) do
		local pos = v.position or {0, 0}
		canvas:drawImage(v.image, { pos[1]+offset[1], pos[2]+offset[2]}, 1, nil, true )
	end
end

function sbq.saveSettings()
	if type(sbq.sbqCurrentData.id) == "number" and sbq.sbqCurrentData.type == "driver" and world.entityExists(sbq.sbqCurrentData.id) then
		world.sendEntityMessage( sbq.sbqCurrentData.id, "settingsMenuSet", sb.jsonMerge(sbq.predatorSettings, sbq.globalSettings))
	end

	sbq.sbqSettings[sbq.sbqCurrentData.species or "sbqOccupantHolder"] = sbq.predatorSettings
	sbq.sbqSettings.global = sbq.globalSettings
	player.setProperty( "sbqSettings", sbq.sbqSettings )
	world.sendEntityMessage( player.id(), "sbqRefreshSettings", sbq.sbqSettings )
end

----------------------------------------------------------------------------------------------------------------

function settings:onClick()
	player.interact("ScriptPane", { gui = { }, scripts = {"/metagui/sbq/build.lua"}, ui = "starbecue:settings" })
end

function escapeValue:onEnter()
	local value = tonumber(escapeValue.text)
	local isNumber = type(value) == "number"
	if isNumber and sbq.overrideSettings.escapeDifficulty == nil and value > 0
	and (
		(sbq.overrideSettings.escapeDifficultyMin == nil and sbq.overrideSettings.escapeDifficultyMax == nil)
		or (sbq.overrideSettings.escapeDifficultyMin <= value and sbq.overrideSettings.escapeDifficultyMax == nil)
		or (sbq.overrideSettings.escapeDifficultyMin == nil and sbq.overrideSettings.escapeDifficultyMax >= value)
		or (sbq.overrideSettings.escapeDifficultyMin <= value and sbq.overrideSettings.escapeDifficultyMax >= value)
	)
	then
		sbq.globalSettings.escapeDifficulty = value
		sbq.saveSettings()
	else
		escapeValue:setText(tostring(sbq.globalSettings.escapeDifficulty or 0))
	end
end

function impossibleEscape:onClick()
	sbq.globalSettings.impossibleEscape = impossibleEscape.checked
	sbq.saveSettings()
end

----------------------------------------------------------------------------------------------------------------

function sbq.drawEffectButton(w, icon)
	local c = widget.bindCanvas(w.backingWidget) c:clear()
	local directives = ""
	if w.state == "press" then directives = "?brightness=-50" end
	local pos = vec2.mul(c:size(), 0.5)

	c:drawImageDrawable(icon..directives, pos, 1)
	if w.checked then
		c:drawImageDrawable(icon.."?outline=1;FFFFFFFF;FFFFFFFF"..directives, pos, 1)
	end
end

function sbq.locationEffectButton(button, location, locationData)
	local value = button:getGroupChecked().value
	local effect = (locationData[value] or {}).effect or (sbq.predatorConfig.effectDefaults or {})[value] or (sbq.config.effectDefaults or {})[value] or "sbqRemoveBellyEffects"
	sbq.globalSettings[location.."EffectSlot"] = value
	sbq.globalSettings[location.."Effect"] = effect
	sbq.saveSettings()
end

function sbq.predUIeffectsPanel(location)
	if not sbq.predatorConfig or not sbq.predatorConfig.locations or not location then return sbq.clearEffectButtons() end
	local locationData = sbq.predatorConfig.locations[location] or {}
	if (locationData.selectEffect or locationData.TF or locationData.Eggify) then
		function noneButton:draw() sbq.drawEffectButton(noneButton, ((locationData.none or {}).icon or "/interface/scripted/sbq/sbqSettings/noEffect.png") ) end
		function healButton:draw() sbq.drawEffectButton(healButton, ((locationData.heal or {}).icon or "/interface/scripted/sbq/sbqSettings/heal.png")) end
		function softDigestButton:draw() sbq.drawEffectButton(softDigestButton, ((locationData.softDigest or {}).icon or "/interface/scripted/sbq/sbqSettings/softDigest.png")) end
		function digestButton:draw() sbq.drawEffectButton(digestButton, ((locationData.digest or {}).icon or "/interface/scripted/sbq/sbqSettings/digest.png")) end
		function eggifyButton:draw() sbq.drawEffectButton(eggifyButton, ((locationData.Eggify or {}).icon or "/interface/scripted/sbq/sbqSettings/eggify.png")) end
		function transformButton:draw() sbq.drawEffectButton(transformButton, ((locationData.TF or {}).icon or "/interface/scripted/sbq/sbqSettings/transform.png")) end

		function noneButton:onClick() sbq.locationEffectButton(noneButton, location, locationData) end
		function healButton:onClick() sbq.locationEffectButton(healButton, location, locationData) end
		function softDigestButton:onClick() sbq.locationEffectButton(softDigestButton, location, locationData) end
		function digestButton:onClick() sbq.locationEffectButton(digestButton, location, locationData) end

		function eggifyButton:onClick() sbq.globalSettings[location.."Eggify"] = eggifyButton.checked sbq.saveSettings() end
		function transformButton:onClick() sbq.globalSettings[location.."TF"] = transformButton.checked sbq.saveSettings() end

		noneButton.toolTip = (locationData.name or location).."\n"..((locationData.none or {}).toolTip or "No effects will be applied to prey.")
		healButton.toolTip = (locationData.name or location).."\n"..((locationData.heal or {}).toolTip or "Prey within will be healed, boosted by your attack power.")
		softDigestButton.toolTip = (locationData.name or location).."\n"..((locationData.softDigest or {}).toolTip or "Prey within will be digested, boosted by your attack power.\nBut they will always retain 1HP.")
		digestButton.toolTip = (locationData.name or location).."\n"..((locationData.digest or {}).toolTip or "Prey within will be digested, boosted by your attack power.")
		eggifyButton.toolTip = (locationData.name or location).."\n"..((locationData.Eggify or {}).toolTip or "Prey within will be trapped in an egg." )
		transformButton.toolTip = (locationData.name or location).."\n"..((locationData.TF or {}).toolTip or "Prey within will be transformed." )

		noneButton:selectValue(sbq.predatorSettings[location.."EffectSlot"] or "none")

		eggifyButton:setChecked(sbq.predatorSettings[location.."Eggify"] or false)
		transformButton:setChecked(sbq.predatorSettings[location.."TF"] or false)

		noneButton:setVisible((locationData.selectEffect and not ((sbq.overrideSettings[location.."Effect"] ~= nil and sbq.overrideSettings[location.."Effect"] ~= ((locationData.none or {}).effect or (sbq.predatorConfig.effectDefaults or {}).none or "sbqRemoveBellyEffects")) or (sbq.overrideSettings[location.."NoneEnable"] == false)) or (sbq.overrideSettings.noneEnable == false)) or false)
		healButton:setVisible((locationData.selectEffect and not ((sbq.overrideSettings[location.."Effect"] ~= nil and sbq.overrideSettings[location.."Effect"] ~= ((locationData.heal or {}).effect or (sbq.predatorConfig.effectDefaults or {}).heal or "sbqHeal")) or (sbq.overrideSettings[location.."HealEnable"] == false)) or (sbq.overrideSettings.healEnable == false)) or false)
		softDigestButton:setVisible((locationData.selectEffect and not ((sbq.overrideSettings[location.."Effect"] ~= nil and sbq.overrideSettings[location.."Effect"] ~= ((locationData.softDigest or {}).effect or (sbq.predatorConfig.effectDefaults or {}).softDigest or "sbqSoftDigest")) or (sbq.overrideSettings[location.."SoftDigestEnable"] == false)) or (sbq.overrideSettings.softDigestEnable == false)) or false)
		digestButton:setVisible((locationData.selectEffect and not ((sbq.overrideSettings[location.."Effect"] ~= nil and sbq.overrideSettings[location.."Effect"] ~= ((locationData.digest or {}).effect or (sbq.predatorConfig.effectDefaults or {}).digest or "sbqDigest")) or (sbq.overrideSettings[location.."DigestEnable"] == false)) or (sbq.overrideSettings.digestEnable == false)) or false)
		eggifyButton:setVisible((locationData.Eggify and not sbq.overrideSettings[location.."Eggify"] ~= nil) or false)
		transformButton:setVisible((locationData.TF and not sbq.overrideSettings[location.."TF"] ~= nil) or false)
	else
		sbq.clearEffectButtons()
	end
end

function sbq.clearEffectButtons()
	noneButton:setVisible(false)
	healButton:setVisible(false)
	softDigestButton:setVisible(false)
	digestButton:setVisible(false)
	eggifyButton:setVisible(false)
	transformButton:setVisible(false)
end

function sbq.cycleLocation(inc)
	local index = (sbq.locationSelectIndex or 1) + inc
	if index > #sbq.predatorConfig.listLocations then
		index = 1
	elseif index < 1 then
		index = #sbq.predatorConfig.listLocations
	end
	sbq.locationSelectIndex = index
	sbq.predatorSettings.lastLocationSelect = sbq.predatorConfig.listLocations[index]
	sbq.predUIeffectsPanel(sbq.predatorSettings.lastLocationSelect)

	local next = index + 1
	if next > #sbq.predatorConfig.listLocations then
		next = 1
	elseif next < 1 then
		next = #sbq.predatorConfig.listLocations
	end
	local prev = index - 1
	if prev > #sbq.predatorConfig.listLocations then
		prev = 1
	elseif prev < 1 then
		prev = #sbq.predatorConfig.listLocations
	end
	local nextLocationData = sbq.predatorConfig.locations[sbq.predatorConfig.listLocations[next]] or {}
	local prevLocationData = sbq.predatorConfig.locations[sbq.predatorConfig.listLocations[prev]] or {}
	prevLocation.toolTip = prevLocationData.name or sbq.predatorConfig.listLocations[prev]
	nextLocation.toolTip = nextLocationData.name or sbq.predatorConfig.listLocations[next]

end

function prevLocation:onClick() sbq.cycleLocation(-1) end
function nextLocation:onClick() sbq.cycleLocation(1) end
