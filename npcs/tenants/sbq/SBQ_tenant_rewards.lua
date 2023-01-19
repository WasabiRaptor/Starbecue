
function sbq.getTenantRewards(rewardTable, occupant, level)
	local setFlags = {}
	local rewards = {}
	for rewardName, data in pairs(rewardTable) do
		if (not occupant.flags[rewardName]) or data.repeatable then
			local giveReward = true
			local time = occupant.visited.totalTime or 0
			local struggleTime = occupant.visited.totalStruggleTime or 0
			local timeCount
			local struggleCount
			if type(data.location) == "string" then
				time = occupant.visited[data.location .. "Time"] or 0
				struggleTime = occupant.visited[data.location .. "StruggleTime"] or 0
			elseif type(data.location) == "table" then
				time = 0
				struggleTime = 0
				for i, location in ipairs(data.location) do
					time = time + (occupant.visited[location .. "Time"] or 0)
					struggleTime = struggleTime + (occupant.visited[location .. "StruggleTime"] or 0)
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


			if giveReward then
				setFlags[rewardName] = true
				local count = 1
				if struggleCount and timeCount then
					count = math.min(struggleCount, timeCount)
				elseif struggleCount then
					count = struggleCount
				elseif timeCount then
					count = timeCount
				end
				rewards[rewardName] = { pool = data.pool, count = count, level = data.level or level }
			end
		end
	end

	return setFlags, rewards
end
