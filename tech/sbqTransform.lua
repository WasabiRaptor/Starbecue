sbq = {}
require "/scripts/any/SBQ_util.lua"
require "/scripts/any/SBQ_RPC_handling.lua"

sbq_transform = {}
function init()
	sbq.config = root.assetJson("/sbq.config")
	sbq.strings = root.assetJson("/sbqStrings.config")
	if not status.statusProperty("sbqSpeciesIdentities") then
		status.setStatusProperty("sbqSpeciesIdentities", {[player.species()] = player.humanoidIdentity()})
	end

	message.setHandler("sbqTransformTechRadialMenuScript", function(_, _, script, ...)
		if not script then return end
		if RadialMenu[script] then
			RadialMenu[script](RadialMenu, ...)
		else
			sb.logInfo(string.format("[%s] Attmpted invalid radial menu script: %s(%s)", entity.id(), script, sb.printJson({...})))
		end
	end)
end

local specialHeldTime
local specialHeld
function update(args)
	sbq.checkRPCsFinished(args.dt)
	if args.moves["special1"] then
		specialHeld = true
		specialHeldTime = specialHeldTime + args.dt
	else
		specialHeld = false
		specialHeldTime = 0
	end

	if RadialMenu.activeMenu then
		if specialHeld then
			RadialMenu:update(args.dt, args)
		else
			RadialMenu:close()
		end
	else
		if (specialHeldTime) > 0.2  then
			RadialMenu:open("TopMenu")
		end
	end
end

RadialMenu = {}
setmetatable(RadialMenu, _RadialMenu)
function RadialMenu:open(menuName, ...)
	if self.activeMenu then
		self.activeMenu:uninit()
	end
	if self[menuName] and self[menuName].isMenu then
		self.activeMenuName = menuName
		self.activeMenu = self[menuName]
		self.activeMenu:init(...)
		setmetatable(self, { __index = self.activeMenu })
	else
		sb.logInfo(string.format("[%s] no radial menu named: %s", entity.id(), menuName))
	end
end
function RadialMenu:close()
	if self.activeMenu then
		self.activeMenu:uninit()
	end
	self.activeMenuName = nil
	self.activeMenu = nil
	player.interact("ScriptPane", {baseConfig = "/interface/scripted/sbq/close/sbqClose.config"}, player.id())
end

_RadialMenu = {isMenu = true}
_RadialMenu.__index = _RadialMenu
function _RadialMenu:init()
end
function _RadialMenu:update()
end
function _RadialMenu:uninit()
end
function _RadialMenu:openRadialMenu(overrides)
	player.interact("ScriptPane", sb.jsonMerge(
		{
			baseConfig = "/interface/scripted/sbq/radialMenu/sbqRadialMenu.config",
			default = {
				onDown = true,
				message = "sbqTransformTechRadialMenuScript"
			},
			cancel = {}
		},
		overrides
	), player.id())
end
local speciesIdentites = {}
local favoriteSpecies = {}
local sortedSpecies = {}
local TopMenu = {}
RadialMenu.TopMenu = TopMenu
setmetatable(TopMenu, _RadialMenu)
function TopMenu:init()
	local options = {
		{
			args = {"open","AssignMenu"},
			icon = "/interface/scripted/sbq/predatorHud/settings.png",
			description = sbq.getString(":assignSpeciesDesc")
		}
	}
	speciesIdentites = status.statusProperty("sbqSpeciesIdentities") or {[player.species()] = player.humanoidIdentity()}
	favoriteSpecies = _ENV.jarray()
	for k, v in pairs(player.getProperty("sbqFavoriteSpecies") or {}) do
		favoriteSpecies[tonumber(k)] = v
	end

	sortedSpecies = {}
	for k, v in pairs(speciesIdentites) do
		if root.speciesConfig(v.species) then
			table.insert(sortedSpecies, k)
		end
	end
	table.sort(sortedSpecies, function (a, b)
		return a < b
	end)

	for i = 1, sbq.config.transformMenuSlots do
		local species = favoriteSpecies[i]
		if species and speciesIdentites[species] and root.speciesConfig(speciesIdentites[species].species) then
			table.insert(options, {
				icon = sbq_transform.getPortrait("bust", species),
				description = sbq_transform.getPortrait("full", species),
				args = { speciesIdentites[species] },
				message = "sbqDoTransformation"
			})
		else
			if species then
				sb.logWarn(species.." is missing.")
			end
			table.insert(options, {
				locked = true
			})
		end
	end

	self:openRadialMenu({ options = options, cancel = {
		script = false,
		message = false
	}})
end

local AssignMenu = {}
RadialMenu.AssignMenu = AssignMenu
setmetatable(AssignMenu, _RadialMenu)
function AssignMenu:init()
	local options = {
		{
			icon = "/interface/scripted/sbq/customize.png",
			args = { "openCharCreation" },
			description = sbq.getString(":customizeDesc")
		}
	}
	for i = 1, sbq.config.transformMenuSlots do
		table.insert(options, {
			name = tostring(i),
			args = {"open", "AssignSlot", i, 0}
		})
	end
	self:openRadialMenu({ options = options,
		default = {
			description = sbq.getString(":assignSpeciesSlot"),
		},
		cancel = {
			args = {"open","TopMenu"}
		}
	})
end

function sbq_transform.getPortrait(portrait, species)
	if not species then return end
	local identity = speciesIdentites[species]
	if not identity then return end
	return root.npcPortrait(portrait, identity.species, "base", 1, 0, { identity = identity, items = {override = {{0,{{}}}}}})
end

local AssignSlot = {}
RadialMenu.AssignSlot = AssignSlot
setmetatable(AssignSlot, _RadialMenu)
function AssignSlot:init(slot, page)
	local index = 1 + (page * sbq.config.transformMenuSlots)
	if not sortedSpecies[index] then
		index = 1
		page = 0
	end
	local options = {
		{
			description = sbq.getString(":nextPage"),
			name = "->",
			args = {"open", "AssignSlot", slot, page+1}
		}
	}
	for i = index, sbq.config.transformMenuSlots * (page + 1) do
		local species = sortedSpecies[i]
		if species then
			table.insert(options, {
				icon = sbq_transform.getPortrait("bust", species),
				description = sbq_transform.getPortrait("full", species),
				args = { "assignFavorite", slot, species },
			})
		else
			table.insert(options, {locked = true})
		end
	end
	self:openRadialMenu({ options = options,
		cancel = {
			args = {"open","AssignMenu"}
		}
	})
end

function _RadialMenu:assignFavorite(slot, species)
	favoriteSpecies[slot] = species
	player.setProperty("sbqFavoriteSpecies", favoriteSpecies)
	self:open("TopMenu")
end
function _RadialMenu:openCharCreation()
	sbq.addRPC(player.characterCreation({ speciesIdentites = speciesIdentites, currentSpecies = player.species()}), function (response)
			status.setStatusProperty("sbqSpeciesIdentities", response.speciesIdentites)
			player.setHumanoidIdentity(response.currentIdentity)
	end)
end

function sbq_transform.getPortrait(portrait, species)
	if not species then return end
	local identity = speciesIdentites[species]
	if not identity then return end
	return root.npcPortrait(portrait, identity.species, "base", 1, 0, { identity = identity, items = {override = {{0,{{}}}}}})
end
