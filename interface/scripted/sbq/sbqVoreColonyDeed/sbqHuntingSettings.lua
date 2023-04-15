---@diagnostic disable: undefined-global
require("/interface/scripted/sbq/sbqSettings/sbqStatsTab.lua")

sbq.fixBehaviorSubTabs = {}
function sbq.huntingSettingsPanel()
	extraTabsPanel:clearChildren()
	extraTabsPanel:addChild({ id = "behaviorTabField", type = "tabField", layout = "horizontal", tabWidth = 40, tabs = {} })
	sbq.fixMainTabSubTab.tenantTab = { behaviorTabField }

	sbq.npcStatsTab()
	sbq.huntingTab()
	sbq.baitingTab()

	function behaviorTabField:onTabChanged(tab, previous)
		local fixSubTabs = sbq.fixBehaviorSubTabs[tab.id]
		if fixSubTabs then
			for i, fixTab in ipairs(fixSubTabs) do
				fixTab:pushEvent("tabChanged", fixTab.currentTab, fixTab.currentTab)
				fixTab:onTabChanged(fixTab.currentTab, fixTab.currentTab)
			end
		end
	end
end

function sbq.npcStatsTab()
	local predPreySlider = { type = "slider", id = "predPreyLeanSlider", extendMax = true,
		notches = { -1, -0.5, 0, 0.5, 1 },
		textToolTips = {"Hard Prey Lean", "Prey Leaning", "Neutral Lean", "Pred Leaning", "Hard Pred Lean"},
		handles = {
			{ value = (sbq.predatorSettings.predPreyLeanMin or -1), locked = sbq.overrideSettings.predPreyLeanMin ~= nil, toolTip = "Prey Lean Limit" },
			{ value = math.max((sbq.predatorSettings.predPreyLean or 0), math.min((sbq.predatorSettings.predPreyLeanMax or 1), (sbq.predatorSettings.predPreyLean or 0))), locked = sbq.predatorSettings.predPreyLean ~= nil, toolTip = "Current Pred/Prey Lean" },
			{ value = (sbq.predatorSettings.predPreyLeanMax or 1), locked = sbq.predatorSettings.predPreyLeanMax ~= nil, toolTip = "Pred Lean Limit" }
		}
	}

	behaviorTabField:newTab({
		type = "tab", id = "statsTab", title = "Stats", visible = true,
		contents = {
			{{type = "label", text = "Prey", inline = true}, predPreySlider, {type = "label", text = "Pred", inline = true}},
			{ id = "statsTabField", type = "tabField", layout = "vertical", tabWidth = 40, tabs = {
			}}
		}
	})
	behaviorTabField.tabs.statsTab:select()
	sbq.fixBehaviorSubTabs.statsTab = { statsTabField }

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
	sbq.fixBehaviorSubTabs.huntingTab = { huntingTabField }

	for i, voreType in pairs(sbq.config.voreTypes) do
		local preferredSize = { type = "slider", id = voreType .. "PreferredSizeSlider", extendMax = true, notches = {0, 0.1, 0.25, 0.5, 0.75, 1, 1.5, 2, 3},
			handles = {
				{ value = (sbq.predatorSettings[voreType .. "PreferredSizeMin"] or 0), locked = sbq.overrideSettings[voreType .. "PreferredSizeMin"] ~= nil, toolTip = "Minimum Relative Prey Size" },
				{ value = math.max((sbq.predatorSettings[voreType .. "PreferredSizeMin"] or 0), math.min((sbq.predatorSettings[voreType .. "PreferredSizeMax"] or 1), (sbq.predatorSettings[voreType .. "PreferredSize"] or 1))), locked = sbq.predatorSettings[voreType .. "PreferredSize"] ~= nil, toolTip = "Preferred Relative Prey Size" },
				{ value = (sbq.predatorSettings[voreType .. "PreferredSizeMax"] or 1), locked = sbq.predatorSettings[voreType .. "PreferredSizeMax"] ~= nil, toolTip = "Maximum Relative Prey Size" }
			}
		}
		local preferredVore = { type = "slider", id = voreType .. "Preferred", notches = {0, 1, 5, 10},
			handles = {
				{ value = (sbq.predatorSettings[voreType .. "Preferred"] or 5), locked = sbq.predatorSettings[voreType .. "PreferredSize"] ~= nil, toolTip = "How much this vore type is preferred by this character" },
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
						{ { type = "checkBox", id = voreType .. "PreferNonImmune",
							toolTip = "Prefer Prey that aren't immune to this location's effects." },
							{ type = "label", text = "Prefer Non Immune" } },
						{ { type = "checkBox", id = voreType .. "DigestHostiles",
							toolTip = "Attempt to digest hostiles with this vore type." },
							{ type = "label", text = "Digest Hostiles" } },
						{ { type = "checkBox", id = voreType .. "HealFriendlies",
							toolTip = "Attempt to heal friendlies with this vore type when they are low health." },
							{ type = "label", text = "Heal Friendlies" } },
						{
							{ type = "panel", style = "flat", children = {
								{ mode = "h" },
								{ type = "label", align = "center", text = "Players" },
								{ type = "checkBox", id = voreType .. "HuntFriendlyPlayers" },
								{ type = "checkBox", id = voreType .. "HuntHostilePlayers" }
							} },
							{ type = "panel", style = "flat", children = {
								{ mode = "h" },
								{ type = "label", align = "center", text = "OCs" },
								{ type = "checkBox", id = voreType .. "HuntFriendlyOCs" },
								{ type = "checkBox", id = voreType .. "HuntHostileOCs" }
							}}
						},
						{
							{ type = "panel", style = "flat", children = {
								{ mode = "h" },
								{ type = "label", align = "center", text = "SBQ NPCs" },
								{ type = "checkBox", id = voreType .. "HuntFriendlySBQNPCs" },
								{ type = "checkBox", id = voreType .. "HuntHostileSBQNPCs" }
							} },
							{ type = "panel", style = "flat", children = {
								{ mode = "h" },
								{ type = "label", align = "center", text = "Other" },
								{ type = "checkBox", id = voreType .. "HuntFriendlyOther" },
								{ type = "checkBox", id = voreType .. "HuntHostileOther" }
							}}
						}
					}}
				}}
			}
		})

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
	sbq.fixBehaviorSubTabs.baitingTab = {baitingTabField}

	for i, voreType in pairs(sbq.config.voreTypes) do

		tab = baitingTabField:newTab({
			type = "tab", id = voreType .. "BaitingTab", visible = sbq.preySettings[voreType] or false, title = "", icon = "/items/active/sbqController/"..voreType..".png", color = "ff00ff", contents = {
				{ type = "scrollArea", scrollDirections = { 0, 1 }, scrollBars = true, thumbScrolling = true, children = {
					{ type = "panel", id = voreType .. "BaitingTabScrollArea", style = "flat", children = {
					}}
				}}
			}
		})
		settingsButtonScripts[voreType] = function()
			tab:setVisible(sbq.preySettings[voreType])
		end


		if i == 1 then
			tab:select()
		end
	end
end
