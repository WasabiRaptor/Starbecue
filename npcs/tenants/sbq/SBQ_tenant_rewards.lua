
function sbq.getTenantRewards(rewardTable, occupant, level)
	local setFlags = {}
	local rewards = {}
	for rewardName, data in pairs(rewardTable) do
		if (not occupant.flags[rewardName]) or data.repeatable then
			local giveReward = true

			local time = occupant.visited.totalTime or 0
			local struggleTime = occupant.visited.totalStruggleTime or 0

			local timeCumulative = occupant.cumulative.totalTime or 0
			local struggleTimeCumulative = occupant.cumulative.totalStruggleTime or 0

			local timeCount
			local struggleCount

			local timeCountCumulative
			local struggleCountCumulative

			local cumulativeFlag

			if type(data.location) == "string" then
				time = occupant.visited[data.location .. "Time"] or 0
				struggleTime = occupant.visited[data.location .. "StruggleTime"] or 0

				timeCumulative = occupant.cumulative[data.location .. "Time"] or 0
				struggleTimeCumulative = occupant.cumulative[data.location .. "StruggleTime"] or 0
				if data.repeatable then
					timeCumulative = timeCumulative - (occupant.cumulativeStart[data.location .. "Time"] or 0)
					struggleTimeCumulative = struggleTimeCumulative - (occupant.cumulativeStart[data.location .. "StruggleTime"] or 0)
				end

			elseif type(data.location) == "table" then
				time = 0
				struggleTime = 0

				timeCumulative = 0
				struggleTimeCumulative = 0

				for i, location in ipairs(data.location) do
					time = time + (occupant.visited[location .. "Time"] or 0)
					struggleTime = struggleTime + (occupant.visited[location .. "StruggleTime"] or 0)

					timeCumulative = timeCumulative + (occupant.cumulative[location .. "Time"] or 0)
					struggleTimeCumulative = struggleTimeCumulative + (occupant.cumulative[location .. "StruggleTime"] or 0)

					if data.repeatable then
						timeCumulative = timeCumulative - (occupant.cumulativeStart[location .. "Time"] or 0)
						struggleTimeCumulative = struggleTimeCumulative - (occupant.cumulativeStart[location .. "StruggleTime"] or 0)
					end
				end
			end

			if giveReward and type(data.minTime) == "number" then
				if time < (data.minTime * 60) then
					giveReward = false
				end
			end
			if giveReward and type(data.minStruggles) == "number" then
				if struggleTime < data.minStruggles then
					giveReward = false
				end
			end

			if giveReward and type(data.time) == "number" then
				local val = (time - ((data.minTime or 0) * 60))
				local comp = (data.time * 60)
				if val < comp then
					giveReward = false
				elseif data.repeatable then
					timeCount = math.floor(val / comp)
				end
			end
			if giveReward and type(data.struggles) == "number" then
				local val = (struggleTime - (data.minStruggles or 0))
				if val < data.struggles then
					giveReward = false
				elseif data.repeatable then
					struggleCount = math.floor(val / data.struggles)
				end
			end

			if giveReward and type(data.minTimeCumulative) == "number" then
				if time < (data.minTimeCumulative * 60) then
					giveReward = false
				end
			end
			if giveReward and type(data.minStrugglesCumulative) == "number" then
				if struggleTime < data.minStrugglesCumulative then
					giveReward = false
				end
			end

			if giveReward and type(data.timeCumulative) == "number" then
				cumulativeFlag = true
				local val = (time - ((data.minTimeCumulative or 0) * 60))
				local comp = (data.timeCumulative * 60)
				if val < comp then
					giveReward = false
				elseif data.repeatable then
					timeCountCumulative = math.floor(val / comp)
				end
			end
			if giveReward and type(data.strugglesCumulative) == "number" then
				cumulativeFlag = true
				local val = (struggleTime - (data.minStrugglesCumulative or 0))
				if val < data.strugglesCumulative then
					giveReward = false
				elseif data.repeatable then
					struggleCountCumulative = math.floor(val / data.strugglesCumulative)
				end
			end

			if giveReward then
				setFlags[rewardName] = true
				local count = math.min(struggleCount or math.huge, timeCount or math.huge, struggleCountCumulative or math.huge, timeCountCumulative or math.huge)
				if count == math.huge then
					count = 1
				end
				rewards[rewardName] = { pool = data.pool, count = count, level = data.level or level, cumulative = cumulativeFlag }
			end
		end
	end

	return setFlags, rewards
end
