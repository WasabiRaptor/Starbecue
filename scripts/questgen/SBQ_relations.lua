
local Item = _ENV.QuestPredicands.Item
local ItemTag = _ENV.QuestPredicands.ItemTag
local ItemList = _ENV.QuestPredicands.ItemList
local Recipe = _ENV.QuestPredicands.Recipe
local Player = _ENV.QuestPredicands.Player
local NullEntity = _ENV.QuestPredicands.NullEntity
local Entity = _ENV.QuestPredicands.Entity
local UnbornNpc = _ENV.QuestPredicands.UnbornNpc
local TemporaryNpc = _ENV.QuestPredicands.TemporaryNpc
local TagSet = _ENV.QuestPredicands.TagSet
local NpcType = _ENV.QuestPredicands.NpcType


-- Check an entity's original species
QuestRelations.sbq_speciesOriginal = defineQueryRelation("sbq_speciesOriginal", true) {
	[case(1, Entity, NonNil)] = function(self, entity, species)
		-- Get the original species value, or default to the usual method if there's not one
		local originalSpecies = entity:callScript("status.statusProperty", "sbqOriginalSpecies") or entity:entitySpecies()
		if xor(self.negated, originalSpecies == species) then
			return { { entity, species } }
		end
		return Relation.empty
	end,

	[case(2, Entity, Nil)] = function(self, entity)
		-- Same as above, but we're returning it instead
		local originalSpecies = entity:callScript("status.statusProperty", "sbqOriginalSpecies") or entity:entitySpecies()
		if self.negated then return Relation.some end
		return { { entity, originalSpecies } }
	end,

	default = Relation.some
}

-- Validate the species given as the first parameter to see if they are installed
-- If they are, the second parameter will be populated with the species
-- I did this because the NPC generator may randomly get the species before the validator and try to generate a species that doesn't exist
-- By giving the NPC generator the second parameter, we can ensure that the species exists before it can try to use it
QuestRelations.sbq_speciesValidate = defineQueryRelation("sbq_speciesValidate", true) {
	-- See if the passed value is a valid species
	[case(1, NonNil, Nil)] = function(self, species)
		local validSpecies = root.speciesConfig(species) ~= nil
		if xor(self.negated, validSpecies) then
			return { { species, species } }
		end
		return Relation.empty
	end,

	-- I tried to return a list of options, but it seems SB will never actually choose one.
	-- There's something about the PoolRelations that lets them actually choose one of the options.

	default = Relation.some
}

-- Check if the NPC is an OC
-- Static, so it can only be used as a precondition, as quests aren't expected to be able to change this
QuestRelations.sbq_isOC = defineQueryRelation("sbq_isOC", true) {
	-- We're given an NPC, so check if it's an OC
	[case(1, Entity)] = function(self, npc)
		-- OC status is a config parameter
		if xor(self.negated, npc:callScript("config.getParameter", "isOC")) then
			return { { npc } }
		end
		return Relation.empty
	end,

	-- No NPC has been chosen/found, so return a list of possible options
	[case(2, Nil)] = function(self)
		if self.negated then return Relation.some end
		-- Return a table of all of the known OCs in context
		local ocList = util.filter(self.context:entitiesByType()["npc"], function(npc)
			return npc:callScript("config.getParameter", "isOC")
		end)
		return util.map(ocList, function(npc)
			return { npc }
		end)
	end,

	default = Relation.empty
}

-- Check if the NPC is a SBQ NPC
QuestRelations.sbq_isSBQ = defineQueryRelation("sbq_isSBQ", true) {
	-- We're given an NPC, so check if it's a SBQ NPC
	[case(1, Entity)] = function(self, npc)
		-- There's a config parameter to check this
		if xor(self.negated, npc:callScript("config.getParameter", "sbqNPC")) then
			return { { npc } }
		end
		return Relation.empty
	end,

	-- No NPC has been chosen/found, so return a list of possible options
	[case(2, Nil)] = function(self)
		if self.negated then return Relation.some end
		-- Return a table of all of the known SBQ NPCs in context
		local sbqList = util.filter(self.context:entitiesByType()["npc"], function(npc)
			return npc:callScript("config.getParameter", "sbqNPC")
		end)
		return util.map(sbqList, function(npc)
			return { npc }
		end)
	end,

	default = Relation.empty
}

-- Check if an entity can be a pred in vore
QuestRelations.sbq_isPred = defineQueryRelation("sbq_isPred", true) {
	-- We're given an NPC and a vore type, so see if they are a pred for that type
	[case(1, Entity, NonNil)] = function(self, entity, predType)
		local isPred = false
		local settings = entity:callScript("status.statusProperty", "sbqPublicSettings") or {}
		if settings.vorePrefs and settings.vorePrefs[predType] then
			isPred = settings.vorePrefs[predType].pred or false
		end
		if xor(self.negated, isPred) then
			return { { entity, predType } }
		end
		return Relation.empty
	end,

	-- There's actually no way to access the player table or the player's entity id with the way things are
	[case(2, Player, NonNil)] = function(self, player, predType)
		-- It's impossible to check
		if self.negated then return Relation.empty end
		-- This returns the parameters given to this function as if it was a valid combo
		return { self.predicands }
	end,

	-- We have an NPC, but no defined vore type, so return the list of vore types they're a pred for
	[case(3, Entity, Nil)] = function(self, entity)
		if self.negated then return Relation.some end

		local results = {}
		local settings = entity:callScript("status.statusProperty", "sbqPublicSettings") or {}
		if settings.vorePrefs then
			for voreType, voreTypeSettings in pairs(settings.vorePrefs) do
				if voreTypeSettings and voreTypeSettings.pred then
					results[#results + 1] = { entity, voreType }
				end
			end
		end
		if #results > 0 then
			return results
		end
		return Relation.empty
	end,

	[case(4, Player, Nil)] = function(self, player)
		-- We can never check. Have it reconsider this one later (after a voreType is found)
		return Relation.some
	end,

	-- Invalid values given? Not a pred.
	default = Relation.empty
}

-- Check if an entity can be prey in vore
QuestRelations.sbq_isPrey = defineQueryRelation("sbq_isPrey", true) {
	-- We're given an NPC and a vore type, so see if they are a prey for that type
	[case(1, Entity, NonNil)] = function(self, entity, preyType)
		local isPrey = false
		local settings = entity:callScript("status.statusProperty", "sbqPublicSettings") or {}
		if settings.vorePrefs and settings.vorePrefs[preyType] then
			isPrey = settings.vorePrefs[preyType].prey or false
		end
		if xor(self.negated, isPrey) then
			return { { entity, preyType } }
		end
		return Relation.empty
	end,

	-- There's actually no way to access the player table or the player's entity id with the way things are
	[case(2, Player, NonNil)] = function(self, player, preyType)
		-- It's impossible to check
		if self.negated then return Relation.empty end
		-- This returns the parameters given to this function as if it was a valid combo
		return { self.predicands }
	end,

	-- We have an NPC, but no defined vore type, so return the list of vore types they're a prey for
	[case(3, Entity, Nil)] = function(self, entity)
		if self.negated then return Relation.some end

		local results = {}
		local settings = entity:callScript("status.statusProperty", "sbqPublicSettings") or {}
		if settings.vorePrefs then
			for voreType, voreTypeSettings in pairs(settings.vorePrefs) do
				if voreTypeSettings and voreTypeSettings.prey then
					results[#results + 1] = { entity, voreType }
				end
			end
		end
		if #results > 0 then
			return results
		end
		return Relation.empty
	end,

	[case(4, Player, Nil)] = function(self, player)
		-- We can never check. Have it reconsider this one later (after a voreType is found)
		return Relation.some
	end,

	-- Invalid values given? Not prey.
	default = Relation.empty
}


-- Check if the NPC can be transformed into a different species
QuestRelations.sbq_canTransformSpecies = defineQueryRelation("sbq_canTransformSpecies", true) {
	[case(1, Entity)] = function(self, npc)
		local settings = npc:callScript("status.statusProperty", "sbqPublicSettings") or {}
		local canTransformSpecies = settings.speciesTF
		if xor(self.negated, canTransformSpecies) then
			return { { npc } }
		end
		return Relation.empty
	end,

	default = Relation.some
}

local _maybeGenerateQuest = maybeGenerateQuest
function maybeGenerateQuest(...)
	if sbq.settings.offerQuests then
		return _maybeGenerateQuest(...)
	end
	return false
end
