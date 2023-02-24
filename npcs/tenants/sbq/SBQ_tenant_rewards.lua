
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

			local timesDigested = occupant.cumulative.totalTimesDigested or 0

			local rewardCounts = {math.huge}

			local cumulativeFlag

			if type(data.location) == "string" then
				time = occupant.visited[data.location .. "Time"] or 0
				struggleTime = occupant.visited[data.location .. "StruggleTime"] or 0

				timeCumulative = occupant.cumulative[data.location .. "Time"] or 0
				struggleTimeCumulative = occupant.cumulative[data.location .. "StruggleTime"] or 0

				timesDigested = occupant.cumulative[data.location .. "TimesDigested"] or 0
			elseif type(data.location) == "table" then
				time = 0
				struggleTime = 0

				timeCumulative = 0
				struggleTimeCumulative = 0

				timesDigested = 0

				for i, location in ipairs(data.location) do
					time = time + (occupant.visited[location .. "Time"] or 0)
					struggleTime = struggleTime + (occupant.visited[location .. "StruggleTime"] or 0)

					timeCumulative = timeCumulative + (occupant.cumulative[location .. "Time"] or 0)
					struggleTimeCumulative = struggleTimeCumulative + (occupant.cumulative[location .. "StruggleTime"] or 0)

					timesDigested = timesDigested + (occupant.cumulative[location .. "TimesDigested"] or 0)
				end
			end

			for name, argData in pairs(data.specialArgs or {}) do
				if type(argData) == "table" then
					local tableName = "visited"
					if argData.cumulative then
						cumulativeFlag = true
						tableName = "cumulative"
					end
					if giveReward and type(argData.min) == "number" then
						if occupant[tableName][name] < (argData.min * (argData.mul or 1)) then
							giveReward = false
						end
					end
					if giveReward and type(argData.value) == "number" then
						local val = (occupant[tableName][name] - ((argData.min or 0) * (argData.mul or 1)))
						local comp = (data.struggleFor)
						if val < comp then
							giveReward = false
						elseif data.repeatable then
							table.insert(rewardCounts, math.floor(val / comp))
						end
					end
					if giveReward and type(argData.max) == "number" then
						if occupant[tableName][name] > (argData.max * (argData.mul or 1)) then
							giveReward = false
						end
					end
				end
			end


			if giveReward and type(data.minStruggleFor) == "number" then
				if occupant.visited.struggleTime < (data.minStruggleFor) then
					giveReward = false
				end
			end
			if giveReward and type(data.struggleFor) == "number" then
				local val = (occupant.visited.struggleTime - (data.minStruggleFor or 0))
				local comp = (data.struggleFor)
				if val < comp then
					giveReward = false
				elseif data.repeatable then
					table.insert(rewardCounts, math.floor(val / comp))
				end
			end
			if giveReward and type(data.maxStruggleFor) == "number" then
				if occupant.visited.struggleTime > (data.maxStruggleFor) then
					giveReward = false
				end
			end

			if giveReward and type(data.minSinceStruggle) == "number" then
				if occupant.visited.sinceLastStruggle < (data.minSinceStruggle) then
					giveReward = false
				end
			end
			if giveReward and type(data.sinceStruggle) == "number" then
				local val = (occupant.visited.sinceLastStruggle - (data.minSinceStruggle or 0))
				local comp = (data.sinceStruggle)
				if val < comp then
					giveReward = false
				elseif data.repeatable then
					table.insert(rewardCounts, math.floor(val / comp))
				end
			end
			if giveReward and type(data.maxSinceStruggle) == "number" then
				if occupant.visited.sinceLastStruggle > (data.maxSinceStruggle) then
					giveReward = false
				end
			end

			if giveReward and type(data.minTime) == "number" then
				if time < (data.minTime * 60) then
					giveReward = false
				end
			end
			if giveReward and type(data.time) == "number" then
				local val = (time - ((data.minTime or 0) * 60))
				local comp = (data.time * 60)
				if val < comp then
					giveReward = false
				elseif data.repeatable then
					table.insert(rewardCounts, math.floor(val / comp))
				end
			end
			if giveReward and type(data.maxTime) == "number" then
				if time > (data.maxTime * 60) then
					giveReward = false
				end
			end

			if giveReward and type(data.minStruggles) == "number" then
				if struggleTime < data.minStruggles then
					giveReward = false
				end
			end
			if giveReward and type(data.struggles) == "number" then
				local val = (struggleTime - (data.minStruggles or 0))
				if val < data.struggles then
					giveReward = false
				elseif data.repeatable then
					table.insert(rewardCounts, math.floor(val / data.struggles))
				end
			end
			if giveReward and type(data.maxStruggles) == "number" then
				if struggleTime > data.maxStruggles then
					giveReward = false
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

			if giveReward and type(data.maxTimeCumulative) == "number" then
				if time < (data.maxTimeCumulative * 60) then
					giveReward = false
				end
			end
			if giveReward and type(data.maxStrugglesCumulative) == "number" then
				if struggleTime < data.maxStrugglesCumulative then
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
					table.insert(rewardCounts, math.floor(val / comp))
				end
			end
			if giveReward and type(data.strugglesCumulative) == "number" then
				cumulativeFlag = true
				local val = (struggleTime - (data.minStrugglesCumulative or 0))
				if val < data.strugglesCumulative then
					giveReward = false
				elseif data.repeatable then
					table.insert(rewardCounts, math.floor(val / data.strugglesCumulative))
				end
			end

			if giveReward and type(data.minTimesDigested) == "number" then
				if timesDigested < data.minTimesDigested then
					giveReward = false
				end
			end
			if giveReward and type(data.timesDigested) == "number" then
				cumulativeFlag = true
				local val = (timesDigested - (data.minTimesDigested or 0))
				if val < data.timesDigested then
					giveReward = false
				elseif data.repeatable then
					table.insert(rewardCounts, math.floor(val / data.timesDigested))
				end
			end
			if giveReward and type(data.maxTimesDigested) == "number" then
				if timesDigested > data.maxTimesDigested then
					giveReward = false
				end
			end


			if giveReward then
				setFlags[rewardName] = true
				local count = math.min(table.unpack(rewardCounts))
				if count == math.huge then
					count = 1
				end
				count = count - (occupant.flags[rewardName .. "CountRecieved"] or 0) - (occupant.flags[rewardName .. "Count"] or 0)
				if count > 0 then
					setFlags[rewardName .. "Count"] = (occupant.flags[rewardName.."Count"] or 0) + count
					rewards[rewardName] = { pool = data.pool, count = count, level = data.level or level, cumulative = cumulativeFlag }
				end
			end
		end
	end
	return setFlags, rewards
end
