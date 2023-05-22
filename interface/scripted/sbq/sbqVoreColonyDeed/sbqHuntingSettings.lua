---@diagnostic disable: undefined-global
require("/interface/scripted/sbq/sbqSettings/sbqStatsTab.lua")

function sbq.huntingSettingsPanel()
	extraTabsPanel:clearChildren()
	extraTabsPanel:addChild({ id = "behaviorTabField", type = "tabField", layout = "horizontal", tabWidth = 40, tabs = {} })
	mainTabField.subTabs.tenantTab = { behaviorTabField }
	behaviorTabField.subTabs = {}

	sbq.npcGeneralBehaviorTab()
	sbq.huntingTab()
	sbq.baitingTab()
	sbq.npcStatsTab()
end

function sbq.npcGeneralBehaviorTab()
	local predPreySlider = { type = "slider", id = "predPreyLeanSlider", extendMax = true,
		notches = { -1, -0.5, 0, 0.5, 1 },
		textToolTips = {"Hard Prey Lean", "Prey Leaning", "Neutral Lean", "Pred Leaning", "Hard Pred Lean"},
		handles = {
			{ value = (sbq.predatorSettings.predPreyLeanMin or -1), locked = sbq.overrideSettings.predPreyLeanMin ~= nil, toolTip = "Prey Lean Limit" },
			{ value = math.max((sbq.predatorSettings.predPreyLean or 0), math.min((sbq.predatorSettings.predPreyLeanMax or 1), (sbq.predatorSettings.predPreyLean or 0))), locked = sbq.overrideSettings.predPreyLean ~= nil, toolTip = "Current Pred/Prey Lean" },
			{ value = (sbq.predatorSettings.predPreyLeanMax or 1), locked = sbq.overrideSettings.predPreyLeanMax ~= nil, toolTip = "Pred Lean Limit" }
		}
	}

	local hungryVisible = sbq.npcConfig.scriptConfig.isHungry
	local hornyVisible = sbq.npcConfig.scriptConfig.isHorny
	local sleepyVisible = sbq.npcConfig.scriptConfig.isSleepy

	local tab = behaviorTabField:newTab({
		type = "tab", id = "behaviorTab", title = "Behavior", visible = true,
		contents = {
			{ { type = "label", text = " Prey", inline = true }, predPreySlider, { type = "label", text = "Pred", inline = true } },
			{
				{ type = "label", text = " " .. (sbq.npcConfig.scriptConfig.hungerLabel or "Hunger"), size = { 40, 10 }, inline = true, visible = hungryVisible },
				{ visible = hungryVisible, id = "hungerBar", type = "fillbar", value = 0, color = sbq.npcConfig.scriptConfig.hungerColor or { 153, 123, 39 } } },
			{
				{ type = "label", text = " " .. (sbq.npcConfig.scriptConfig.restLabel or "Rest"), size = { 40, 10 }, inline = true, visible = sleepyVisible },
				{ visible = sleepyVisible, id = "restBar", type = "fillbar", value = 0, color = sbq.npcConfig.scriptConfig.restColor or { 179, 135, 215 } }
			},
			{
				{ type = "label", text = " " .. (sbq.npcConfig.scriptConfig.hornyLabel or "Horny"), size = { 40, 10 }, inline = true, visible = hornyVisible },
				{ visible = hornyVisible, id = "hornyBar", type = "fillbar", value = 0, color = sbq.npcConfig.scriptConfig.hornyColor or { 226, 109, 215 } }
			},
			{ { type = "checkBox", id = "preferNonImmune",
				toolTip = "Prefer Prey that aren't immune to this location's effects." },
				{ type = "label", text = "Prefer Non Immune" } },
			{ { type = "checkBox", id = "preferDigestHostiles",
				toolTip = "Attempt to digest hostiles with this vore type." },
				{ type = "label", text = "Digest Hostiles" } },
			{ { type = "checkBox", id = "preferHealFriendlies",
				toolTip = "Attempt to heal friendlies with this vore type when they are low health." },
				{ type = "label", text = "Heal Friendlies" } },
		}
	})
	function predPreyLeanSlider:onChange(index, value)
		if index == 1 then
			sbq.changePredatorSetting("predPreyLeanMin", value)
		elseif index == 2 then
			sbq.changePredatorSetting("predPreyLean", value)
		elseif index == 3 then
			sbq.changePredatorSetting("predPreyLeanMax", value)
		end
	end

	function tab:update(dt)
		sbq.loopedMessage("getHunger", sbq.tenant.uniqueId, "sbqGetResourcePercentage", {"food"}, function (value)
			hungerBar:setValue(value)
		end )
		sbq.loopedMessage("getHorny", sbq.tenant.uniqueId, "sbqGetResourcePercentage", {"horny"}, function (value)
			hornyBar:setValue(value)
		end)
		sbq.loopedMessage("getRest", sbq.tenant.uniqueId, "sbqGetResourcePercentage", {"rest"}, function (value)
			restBar:setValue(value)
		end )
	end
end


function sbq.npcStatsTab()
	behaviorTabField:newTab({
		type = "tab", id = "statsTab", title = "Stats", visible = true,
		contents = {
			{ id = "statsTabField", type = "tabField", layout = "vertical", tabWidth = 40, tabs = {
			}}
		}
	})

	behaviorTabField.subTabs.statsTab = { statsTabField }

	sbq.statsTab()
end



function sbq.huntingTab()
	behaviorTabField:newTab({
		type = "tab", id = "huntingTab", title = "Hunting", visible = true,
		contents = {
			{ id = "huntingTabField", type = "tabField", layout = "vertical", tabWidth = 18, tabs = {
			}}
		}
	})
	--behaviorTabField.tabs.huntingTab:select()
	behaviorTabField.subTabs.huntingTab = { huntingTabField }

	for i, voreType in pairs(sbq.config.voreTypes) do
		local preferredSize = { type = "slider", id = voreType .. "PreferredPreySizeSlider", extendMax = true, notches = {0.1, 0.25, 0.5, 0.75, 1, 1.5, 2, 2.5, 3},
			handles = {
				{ value = (sbq.predatorSettings[voreType .. "PreferredPreySizeMin"] or 0.1), locked = sbq.overrideSettings[voreType .. "PreferredPreySizeMin"] ~= nil, toolTip = "Minimum Relative Prey Size" },
				{ value = math.max((sbq.predatorSettings[voreType .. "PreferredPreySizeMin"] or 0.1), math.min((sbq.predatorSettings[voreType .. "PreferredPreySizeMax"] or 1.25), (sbq.predatorSettings[voreType .. "PreferredPreySize"] or 0.5))), locked = sbq.overrideSettings[voreType .. "PreferredPreySize"] ~= nil, toolTip = "Preferred Relative Prey Size" },
				{ value = (sbq.predatorSettings[voreType .. "PreferredPreySizeMax"] or 1.25), locked = sbq.overrideSettings[voreType .. "PreferredPreySizeMax"] ~= nil, toolTip = "Maximum Relative Prey Size" }
			}
		}
		local preferredVore = { type = "slider", id = voreType .. "PreferredPred", min = 0, max = 10, snapOnly = true,
			textToolTips = {"Never"},
			handles = {
				{ value = (sbq.predatorSettings[voreType .. "PreferredPred"] or 5), locked = sbq.overrideSettings[voreType .. "PreferredPred"] ~= nil, toolTip = "How much this vore type is preferred by this character as a pred." },
			}
		}
		local consentSlider = { type = "slider", id = voreType .. "ConsentPred", notches = {0,0.25,0.5,0.75,1},
			textToolTips = {"Never", "Unlikely", "Sometimes", "Likely", "Always"},
			handles = {
				{ value = (sbq.predatorSettings[voreType .. "ConsentPred"] or 0.5), locked = sbq.overrideSettings[voreType .. "ConsentPred"] ~= nil, toolTip = "How often the NPC will ask for consent." },
			}
		}
		tab = huntingTabField:newTab({
			type = "tab", id = voreType .. "HuntingTab", visible = sbq.predatorSettings[voreType.."Pred"] or false, title = "", icon = "/items/active/sbqController/"..voreType..".png", color = "ff00ff", contents = {
				{ type = "scrollArea", scrollDirections = { 0, 1 }, scrollBars = true, thumbScrolling = true, children = {
					{ type = "panel", id = voreType .. "HuntingTabScrollArea", style = "flat", children = {
						{ mode = "v" },
						{type = "label", align = "center", text = "Preference To "..sbq.config.voreTypeNames[voreType]},
						preferredVore,
						{type = "label", align = "center", text = "Preferred Relative Prey Size"},
						preferredSize,
						{type = "label", align = "center", text = "Requesting Consent"},
						consentSlider,
						{
							{ type = "panel", style = "flat", children = {
								{ mode = "h" },
								{ type = "label", align = "center", text = "Players" },
								{ type = "iconCheckBox", id = voreType .. "HuntFriendlyPlayers", toolTip = "Friendly", icon = "/interface/scripted/sbq/sbqSettings/friendly.png" },
								{ type = "iconCheckBox", id = voreType .. "HuntHostilePlayers", toolTip = "Hostile", icon = "/interface/scripted/sbq/sbqSettings/hostile.png" }
							} },
							{ type = "panel", style = "flat", children = {
								{ mode = "h" },
								{ type = "label", align = "center", text = "OCs" },
								{ type = "iconCheckBox", id = voreType .. "HuntFriendlyOCs", toolTip = "Friendly", icon = "/interface/scripted/sbq/sbqSettings/friendly.png" },
								{ type = "iconCheckBox", id = voreType .. "HuntHostileOCs", toolTip = "Hostile", icon = "/interface/scripted/sbq/sbqSettings/hostile.png" }
							}}
						},
						{
							{ type = "panel", style = "flat", children = {
								{ mode = "h" },
								{ type = "label", align = "center", text = "SBQ NPCs" },
								{ type = "iconCheckBox", id = voreType .. "HuntFriendlySBQNPCs", toolTip = "Friendly", icon = "/interface/scripted/sbq/sbqSettings/friendly.png" },
								{ type = "iconCheckBox", id = voreType .. "HuntHostileSBQNPCs", toolTip = "Hostile", icon = "/interface/scripted/sbq/sbqSettings/hostile.png" }
							} },
							{ type = "panel", style = "flat", children = {
								{ mode = "h" },
								{ type = "label", align = "center", text = "Other" },
								{ type = "iconCheckBox", id = voreType .. "HuntFriendlyOther", toolTip = "Friendly", icon = "/interface/scripted/sbq/sbqSettings/friendly.png" },
								{ type = "iconCheckBox", id = voreType .. "HuntHostileOther", toolTip = "Hostile", icon = "/interface/scripted/sbq/sbqSettings/hostile.png" }
							}}
						}
					}}
				}}
			}
		})

		local preferredVoreSlider = _ENV[voreType .. "PreferredPred"]
		function preferredVoreSlider:onChange(index, value)
			if index == 1 then
				sbq.changePredatorSetting(voreType .. "PreferredPred", value)
			end
		end
		local consentSliderWidget = _ENV[voreType .. "ConsentPred"]
		function consentSliderWidget:onChange(index, value)
			if index == 1 then
				sbq.changePredatorSetting(voreType .. "ConsentPred", value)
			end
		end

		local PreferredSizeSlider = _ENV[voreType .. "PreferredPreySizeSlider"]
		function PreferredSizeSlider:onChange(index, value)
			if index == 1 then
				sbq.changePredatorSetting(voreType .. "PreferredPreySizeMin", value)
			elseif index == 2 then
				sbq.changePredatorSetting(voreType .. "PreferredPreySize", value)
			elseif index == 3 then
				sbq.changePredatorSetting(voreType .. "PreferredPreySizeMax", value)
			end
		end

		settingsButtonScripts[voreType .. "Pred"] = function()
			tab:setVisible(sbq.predatorSettings[voreType .. "Pred"])
		end

		if i == 1 then
			tab:select()
		end
	end
end

function sbq.baitingTab()
	behaviorTabField:newTab({
		type = "tab", id = "baitingTab", title = "Baiting", visible = true,
		contents = {
			{ id = "baitingTabField", type = "tabField", layout = "vertical", tabWidth = 18, tabs = {
			}}
		}
	})
	behaviorTabField.subTabs.baitingTab = {baitingTabField}

	for i, voreType in pairs(sbq.config.voreTypes) do

		local preferredSize = { type = "slider", id = voreType .. "PreferredPredSizeSlider", extendMax = true, notches = {0.1, 0.25, 0.5, 0.75, 1, 1.5, 2, 2.5, 3},
			handles = {
				{ value = (sbq.predatorSettings[voreType .. "PreferredPredSizeMin"] or 0.75), locked = sbq.overrideSettings[voreType .. "PreferredPredSizeMin"] ~= nil, toolTip = "Minimum Relative Pred Size" },
				{ value = math.max((sbq.predatorSettings[voreType .. "PreferredPredSizeMin"] or 0.75), math.min((sbq.predatorSettings[voreType .. "PreferredPredSizeMax"] or 3), (sbq.predatorSettings[voreType .. "PreferredPredSize"] or 2))), locked = sbq.overrideSettings[voreType .. "PreferredPredSize"] ~= nil, toolTip = "Preferred Relative Pred Size" },
				{ value = (sbq.predatorSettings[voreType .. "PreferredPredSizeMax"] or 3), locked = sbq.overrideSettings[voreType .. "PreferredPredSizeMax"] ~= nil, toolTip = "Maximum Relative Pred Size" }
			}
		}
		local preferredVore = { type = "slider", id = voreType .. "PreferredPrey", min = 0, max = 10, snapOnly = true,
			textToolTips = {"Never"},
			handles = {
				{ value = (sbq.predatorSettings[voreType .. "PreferredPrey"] or 5), locked = sbq.overrideSettings[voreType .. "PreferredPrey"] ~= nil, toolTip = "How much this vore type is preferred by this character as prey." },
			}
		}
		local consentSlider = { type = "slider", id = voreType .. "ConsentPrey", notches = {0,0.25,0.5,0.75,1},
			textToolTips = {"Never", "Unlikely", "Sometimes", "Likely", "Always"},
			handles = {
				{ value = (sbq.predatorSettings[voreType .. "ConsentPrey"] or 0.5), locked = sbq.overrideSettings[voreType .. "ConsentPrey"] ~= nil, toolTip = "How often the NPC will ask for consent." },
			}
		}
		local preferredEffects = { id = "preferredEffectsPanel", type = "panel", style = "flat", children = {
			{ mode = "v" },
			{type = "label", align = "center", text = "Liked Effects"},
			{
				{{
					type = "iconCheckBox", id = voreType .. "PreyPrefersNone",
					checked = sbq.predatorSettings[voreType .. "PreyPrefersNone"],
					icon = "/interface/scripted/sbq/sbqSettings/noEffect.png",
					toolTip = "Preds with no effect will be prefered.",
				}},
				{{
					type = "iconCheckBox", id = voreType .. "PreyPrefersHeal",
					checked = sbq.predatorSettings[voreType .. "PreyPrefersHeal"],
					icon = "/interface/scripted/sbq/sbqSettings/heal.png",
					toolTip = "Preds with a healing effect will be prefered.",
				}},
				{{
					type = "iconCheckBox", id = voreType .. "PreyPrefersSoftDigest",
					checked = sbq.predatorSettings[voreType .. "PreyPrefersSoftDigest"],
					icon = "/interface/scripted/sbq/sbqSettings/softDigest.png",
					toolTip = "Preds with a soft digest effect will be prefered.",

				}},
				{{
					type = "iconCheckBox", id = voreType .. "PreyPrefersDigest",
					checked = sbq.predatorSettings[voreType .. "PreyPrefersDigest"],
					icon = "/interface/scripted/sbq/sbqSettings/digest.png",
					toolTip = "Preds with a digest effect will be prefered.",
				}},
			}
		}}
		local dislikedEffects = { id = "dislikedEffectsPanel", type = "panel", style = "flat", children = {
			{ mode = "v" },
			{type = "label", align = "center", text = "Disliked Effects"},
			{
				{{
					type = "iconCheckBox", id = voreType .. "PreyDislikesNone",
					checked = sbq.predatorSettings[voreType .. "PreyDislikesNone"],
					icon = "/interface/scripted/sbq/sbqSettings/noEffect.png",
					toolTip = "Preds with no effect will not be considered.",
				}},
				{{
					type = "iconCheckBox", id = voreType .. "PreyDislikesHeal",
					checked = sbq.predatorSettings[voreType .. "PreyDislikesHeal"],
					icon = "/interface/scripted/sbq/sbqSettings/heal.png",
					toolTip = "Preds with a heal effect will not be considered.",
				}},
				{{
					type = "iconCheckBox", id = voreType .. "PreyDislikesSoftDigest",
					checked = sbq.predatorSettings[voreType .. "PreyDislikesSoftDigest"],
					icon = "/interface/scripted/sbq/sbqSettings/softDigest.png",
					toolTip = "Preds with a soft digest effect will not be considered.",
				}},
				{{
					type = "iconCheckBox", id = voreType .. "PreyDislikesDigest",
					checked = sbq.predatorSettings[voreType .. "PreyDislikesDigest"],
					icon = "/interface/scripted/sbq/sbqSettings/digest.png",
					toolTip = "Preds with a digest effect will not be considered.",
				}},
			}
		}}

		tab = baitingTabField:newTab({
			type = "tab", id = voreType .. "BaitingTab", visible = sbq.preySettings[voreType] or false, title = "", icon = "/items/active/sbqController/"..voreType..".png", color = "ff00ff", contents = {
				{ type = "scrollArea", scrollDirections = { 0, 1 }, scrollBars = true, thumbScrolling = true, children = {
					{ type = "panel", id = voreType .. "BaitingTabScrollArea", style = "flat", children = {
						{ mode = "v" },
						{type = "label", align = "center", text = "Preference To "..sbq.config.voreTypeNames[voreType]},
						preferredVore,
						{type = "label", align = "center", text = "Preferred Relative Pred Size"},
						preferredSize,
						{type = "label", align = "center", text = "Requesting Consent"},
						consentSlider,
						{
							preferredEffects, dislikedEffects
						},
						{
							{ type = "panel", style = "flat", children = {
								{ mode = "h" },
								{ type = "label", align = "center", text = "Players" },
								{ type = "iconCheckBox", id = voreType .. "BaitFriendlyPlayers", toolTip = "Friendly", icon = "/interface/scripted/sbq/sbqSettings/friendly.png" },
								{ type = "iconCheckBox", id = voreType .. "BaitHostilePlayers", toolTip = "Hostile", icon = "/interface/scripted/sbq/sbqSettings/hostile.png" }
							} },
							{ type = "panel", style = "flat", children = {
								{ mode = "h" },
								{ type = "label", align = "center", text = "OCs" },
								{ type = "iconCheckBox", id = voreType .. "BaitFriendlyOCs", toolTip = "Friendly", icon = "/interface/scripted/sbq/sbqSettings/friendly.png" },
								{ type = "iconCheckBox", id = voreType .. "BaitHostileOCs", toolTip = "Hostile", icon = "/interface/scripted/sbq/sbqSettings/hostile.png" }
							}}
						},
						{
							{ type = "panel", style = "flat", children = {
								{ mode = "h" },
								{ type = "label", align = "center", text = "SBQ NPCs" },
								{ type = "iconCheckBox", id = voreType .. "BaitFriendlySBQNPCs", toolTip = "Friendly", icon = "/interface/scripted/sbq/sbqSettings/friendly.png" },
								{ type = "iconCheckBox", id = voreType .. "BaitHostileSBQNPCs", toolTip = "Hostile", icon = "/interface/scripted/sbq/sbqSettings/hostile.png" }
							} },
							{ type = "panel", style = "flat", children = {
								{ mode = "h" },
								{ type = "label", align = "center", text = "Other" },
								{ type = "iconCheckBox", id = voreType .. "BaitFriendlyOther", toolTip = "Friendly", icon = "/interface/scripted/sbq/sbqSettings/friendly.png" },
								{ type = "iconCheckBox", id = voreType .. "BaitHostileOther", toolTip = "Hostile", icon = "/interface/scripted/sbq/sbqSettings/hostile.png" }
							}}
						}

					}}
				}}
			}
		})
		settingsButtonScripts[voreType] = function()
			tab:setVisible(sbq.preySettings[voreType])
		end

		local preferredVoreSlider = _ENV[voreType .. "PreferredPrey"]
		function preferredVoreSlider:onChange(index, value)
			if index == 1 then
				sbq.changePredatorSetting(voreType .. "PreferredPrey", value)
			end
		end
		local consentSliderWidget = _ENV[voreType .. "ConsentPrey"]
		function consentSliderWidget:onChange(index, value)
			if index == 1 then
				sbq.changePredatorSetting(voreType .. "ConsentPrey", value)
			end
		end


		local PreferredSizeSlider = _ENV[voreType .. "PreferredPredSizeSlider"]
		function PreferredSizeSlider:onChange(index, value)
			if index == 1 then
				sbq.changePredatorSetting(voreType .. "PreferredPredSizeMin", value)
			elseif index == 2 then
				sbq.changePredatorSetting(voreType .. "PreferredPredSize", value)
			elseif index == 3 then
				sbq.changePredatorSetting(voreType .. "PreferredPredSizeMax", value)
			end
		end


		if i == 1 then
			tab:select()
		end
	end
end
