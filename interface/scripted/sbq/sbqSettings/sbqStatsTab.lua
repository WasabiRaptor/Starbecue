---@diagnostic disable: undefined-global
function sbq.statsTab()

	local totalLocationTimes = {
		pred = {},
		prey = {},
		name = "Overall"
	}
	for uuid, data in pairs(sbq.cumulativeData or {}) do
		for thing, value in pairs(data.pred or {}) do
			if type(value) == "number" then
				totalLocationTimes.pred[thing] = (totalLocationTimes.pred[thing] or 0) + value
			end
		end
		for thing, value in pairs(data.prey or {}) do
			if type(value) == "number" then
				totalLocationTimes.prey[thing] = (totalLocationTimes.prey[thing] or 0) + value
			end
		end
	end

	for i, location in pairs(sbq.config.listLocations) do
		local defaultLocationData = sbq.config.defaultLocationData[location]
		local tabVisible = true
		if defaultLocationData.voreTypes then
			for i, voreType in ipairs(defaultLocationData.voreTypes) do
				tabVisible = (
					((sbq.playerPreySettings)[voreType] or sbq.playerPredatorSettings[voreType .. "Pred"] or false)
					and (sbq.preySettings[voreType] or sbq.predatorSettings[voreType .. "Pred"] or false)
				)
				if tabVisible then break end
			end
		end

		local dataPanels = {
			sbq.getOccupancyStatLayout(nil, totalLocationTimes, location, defaultLocationData),
		}
		if sbq.playeruuid and sbq.cumulativeData[sbq.playeruuid] then
			table.insert(dataPanels, sbq.getOccupancyStatLayout(nil, sbq.cumulativeData[sbq.playeruuid], location, defaultLocationData)
		)
		end
		local players = {}
		local ocs = {}
		local sbqNPCs = {}
		local other = {}

		for uuid, data in pairs(sbq.cumulativeData) do
			if uuid ~= sbq.playeruuid then
				local entry = sbq.getOccupancyStatLayout(uuid, data, location, defaultLocationData)
				if data.type == "player" then
					table.insert(players, entry)
				elseif data.type == "npc" then
					if data.typeName then
						local success, npcConfig = pcall(root.npcConfig, (data.typeName))
						if success and ((npcConfig or {}).scriptConfig or {}).isOC then
							table.insert(ocs, entry)
						elseif success and ((npcConfig or {}).scriptConfig or {}).sbqNPC then
							table.insert(sbqNPCs, entry)
						else
							table.insert(other, entry)
						end
					else
						table.insert(other, entry)
					end
				else
					table.insert(other, entry)
				end
			end
		end
		table.sort(players, sbq.sortStatEntries)
		table.sort(ocs, sbq.sortStatEntries)
		table.sort(sbqNPCs, sbq.sortStatEntries)
		table.sort(other, sbq.sortStatEntries)

		util.appendLists(dataPanels, players)
		util.appendLists(dataPanels, ocs)
		util.appendLists(dataPanels, sbqNPCs)
		util.appendLists(dataPanels, other)

		table.insert(dataPanels, {
			{expandMode = {2,2}}
		})

		tab = statsTabField:newTab({
			type = "tab", id = location .. "StatsTab", visible = tabVisible, title = defaultLocationData.name or location, color = "ff00ff", contents = {
				{ type = "scrollArea", scrollDirections = { 0, 1 }, scrollBars = true, thumbScrolling = true, children = {
					{ type = "panel", id = location .. "StatsTabScrollArea", style = "flat", children = dataPanels}
				}}
			}
		})
		if i == 1 then
			tab:select()
		end
	end

end
function sbq.sortStatEntries(a, b)
	return a.children[2].text < b.children[2].text
end

function sbq.getOccupancyStatLayout(uuid, data, location, locationData)
	local predVisble
	local preyVisible
	if locationData.voreTypes then
		for i, voreType in ipairs(locationData.voreTypes) do
			predVisble = predVisble or sbq.predatorSettings[voreType .. "Pred"] or false
			preyVisible = preyVisible or sbq.preySettings[voreType] or false
			if preyVisible and predVisble then break end
		end
	end
	local color
	if data.type == "player" then
		color = "893EC5"
	elseif data.type == "npc" then
		if data.entityType then
			local success, npcConfig = pcall(root.npcConfig, (data.typeName))
			if success and ((npcConfig or {}).scriptConfig or {}).isOC then
				color = "3EA8C5"
			elseif success and ((npcConfig or {}).scriptConfig or {}).sbqNPC then
				color = "42C53E"
			end
		end
	end
	return { type = "panel", style = "flat", expandMode = {1,0}, color = color, children = {
		{mode = "vertical"},
		{ type = "label", text = data.name or uuid or "-", align = "center" },
		{
			{ type = "panel", style = "flat", visible = preyVisible, color = "0003FF", children = {
				{ type = "label", text = "As Prey:" },
				{ type = "label", text = sbq.getTimeString((data.pred or {})[location .. "Time"] or 0) },
				{ type = "spacer" },
				{ type = "label", text = "Struggles:"  },
				{ type = "label", text = sbq.getTimeString((data.pred or {})[location .. "StruggleTime"] or 0) },
				{ type = "spacer" },
				{ { type = "label", text = "Digested:", inline = true }, { type = "label", text = ((data.pred or {})[location .. "TimesDigested"] or 0), inline = true } },
				{ { type = "label", text = "Climaxed:", inline = true }, { type = "label", text = ((data.pred or {})[location .. "TimesClimaxed"] or 0), inline = true }}
			}},
			{ type = "panel", style = "flat", visible = predVisble, color = "FF8201", children = {
				{ type = "label", text = "As Pred:" },
				{ type = "label", text = sbq.getTimeString((data.prey or {})[location.."Time"] or 0) },
				{ type = "spacer" },
				{ type = "label", text = "Struggles:" },
				{ type = "label", text = sbq.getTimeString((data.prey or {})[location .. "StruggleTime"] or 0) },
				{ type = "spacer" },
				{ { type = "label", text = "Digested:", inline = true }, { type = "label", text = ((data.prey or {})[location .. "TimesDigested"] or 0), inline = true } },
				{ { type = "label", text = "Climaxed:", inline = true }, { type = "label", text = ((data.prey or {})[location .. "TimesClimaxed"] or 0), inline = true }}
			}}
		}
	}}
end

function sbq.twoDigits(input)
	if #input == 1 then
		return "0"..input
	end
	return input
end

function sbq.getTimeString(time)
	local days = tostring(math.floor(time/86400))
	local hours = tostring(math.floor(time/3600) % 24)
	local mins = tostring(math.floor(time/60) % 60)
	local seconds = tostring(math.floor(time) % 60)
	return sbq.twoDigits(days)..":"..sbq.twoDigits(hours)..":"..sbq.twoDigits(mins)..":"..sbq.twoDigits(seconds)
end
