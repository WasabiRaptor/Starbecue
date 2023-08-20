local pressedTime = 0
local rpc
local rpcCallback
local radialMenuOpen = false
local settings
local inited = false
local spawnCooldown = 1
local spawnedVehicle = nil

sbq = {}
require("/scripts/SBQ_RPC_handling.lua")

function init()
	message.setHandler( "sbqRefreshSettings", function(_,_, newSettings) -- this only ever gets called when the prey despawns or other such occasions, we kinda hijack it for other purposes on the player
		settings = newSettings
	end)
end

function update(args)
	if not inited then
		inited = true
		sbq.addRPC(world.sendEntityMessage( entity.id(), "sbqLoadSettings" ), function (result)
			settings = result
		end)
	end
	sbq.checkRPCsFinished(args.dt)

	if args.moves["special1"] then
		pressedTime = pressedTime + args.dt
		if pressedTime >= 0.2 then -- long hold
			if not radialMenuOpen then
				openRadialMenu()
				radialMenuOpen = true
			else
				sbq.loopedMessage("radialSelect", entity.id(), "sbqGetRadialSelection", {}, function(data)
					if data.selection ~= nil and data.type == "sbqSelect" then
						sbq.lastRadialSelection = data.selection
						sbq.radialSelectionType = data.type
						if data.selection == "cancel" or data.selection == "settings" then return end
						if data.pressed and not sbq.click then
							world.sendEntityMessage(entity.id(), "sbqOpenInterface", "sbqClose")
							spawnPredator(data.selection)
							radialMenuOpen = false
							return
						end
						if data.button == 0 and not sbq.click then
						elseif data.button == 2 and not sbq.click then
						end
						sbq.click = data.pressed
					end
				end)
			end
		end
	elseif radialMenuOpen then
		world.sendEntityMessage(entity.id(), "sbqOpenInterface", "sbqClose")
		if sbq.radialSelectionType == "sbqSelect" then
			if sbq.lastRadialSelection == "settings" then
				openSettingsMenu()
			elseif sbq.lastRadialSelection ~= "cancel" then
				spawnPredator(sbq.lastRadialSelection)
			end
		end
		radialMenuOpen = false
	else
		pressedTime = 0
	end
	spawnCooldown = math.max(0, spawnCooldown - args.dt)
	pressed = args.moves["special1"]
end

function spawnPredator(pred)
	if (not spawnedVehicle or not world.entityExists(spawnedVehicle)) and spawnCooldown <= 0 then
		spawnCooldown = 1
		local currentData = status.statusProperty("sbqCurrentData") or {}
		spawnedVehicle = world.spawnVehicle( pred, mcontroller.position(), { driver = entity.id(), settings = sb.jsonMerge(settings[pred] or {}, settings.global or {}), direction = mcontroller.facingDirection(), retrievePrey = currentData.id } )
	end
end

function openRadialMenu()
	local options = {{
		name = "settings",
		icon = "/interface/title/modsover.png"
	}}
	if settings and settings.types then
		for pred, data in pairs(settings.types) do
			if data.enable then
				local skin = (settings[pred].skinNames or {}).head or "default"
				local directives = setColorReplaceDirectives(root.assetJson("/vehicles/sbq/"..pred.."/"..pred..".vehicle").sbqData, settings[pred] or {}) or ""
				if #options <= 10 then
					if data.index ~= nil and data.index+1 <= #options then
						table.insert(options, data.index+1, {
							name = pred,
							icon = "/vehicles/sbq/"..pred.."/skins/"..skin.."/icon.png"..directives
						})
					else
						table.insert(options, {
							name = pred,
							icon = "/vehicles/sbq/"..pred.."/skins/"..skin.."/icon.png"..directives
						})
					end
				end
			end
		end
	end

	world.sendEntityMessage( entity.id(), "sbqOpenInterface", "sbqRadialMenu", {options = options, type = "sbqSelect"} )
end
function openSettingsMenu()
	world.sendEntityMessage( entity.id(), "sbqOpenMetagui", "starbecue:predatorSelectorSettings" )
end
function closeMenu()
	world.sendEntityMessage( entity.id(), "sbqOpenInterface", "sbqClose" )
end

function setColorReplaceDirectives(predatorConfig, predatorSettings)
	if predatorConfig.replaceColors ~= nil then
		local colorReplaceString = ""
		for i, colorGroup in ipairs(predatorConfig.replaceColors) do
			local basePalette = colorGroup[1]
			local replacePalette = colorGroup[((predatorSettings.replaceColors or {})[i] or (predatorConfig.defaultSettings.replaceColors or {})[i] or 1) + 1]
			local fullbright = (predatorSettings.fullbright or {})[i]

			if predatorSettings.replaceColorTable and predatorSettings.replaceColorTable[i] then
				replacePalette = predatorSettings.replaceColorTable[i]
				if type(replacePalette) == "string" then
					return replacePalette
				end
			end

			for j, color in ipairs(replacePalette) do
				if fullbright and #color <= #"ffffff" then -- don't tack it on it if it already has a defined opacity or fullbright
					color = color.."fe"
				end
				colorReplaceString = colorReplaceString.."?replace;"..(basePalette[j] or "").."="..(color or "")
			end
		end
		return colorReplaceString
	end
end
