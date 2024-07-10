function sbq.checkRPCsFinished(dt)
	local finished = {}
	for i, entry in ipairs(sbq.rpcList) do
		entry.dt = entry.dt + dt -- I think this is good to have, incase the time passed since the RPC was put into play is important
		if sbq.checkRPCFinished(entry.rpc, entry.callback, entry.failCallback, entry.dt) then
			table.insert(finished, 1, i)
		end
	end
	for _, i in ipairs(finished) do
		table.remove(sbq.rpcList, i)
	end
	for name, entry in pairs(sbq.namedRPCList) do
		entry.dt = entry.dt + dt -- I think this is good to have, incase the time passed since the RPC was put into play is important
		if sbq.checkRPCFinished(entry.rpc, entry.callback, entry.failCallback, entry.dt) then
			sbq.namedRPCList[name] = nil
		end
	end
end

function sbq.checkRPCFinished(rpc, callback, failCallback, ...)
	if rpc:finished() then
		if rpc:succeeded() and callback then
			callback(rpc:result(), ...)
		elseif failCallback ~= nil then
			failCallback(false, ...)
		end
		return true
	end
	return false
end

sbq.rpcList = {}
function sbq.addRPC(rpc, callback, failCallback, ...)
	if not rpc then return end
	if not sbq.checkRPCFinished(rpc, callback, failCallback, 0, ...) then
		if callback ~= nil or failCallback ~= nil  then
			table.insert(sbq.rpcList, {rpc = rpc, callback = callback, failCallback = failCallback, dt = 0, args = {...}})
		end
	end
end

sbq.namedRPCList = {}
function sbq.addNamedRPC(name, rpc, callback, failCallback, ...)
	if not rpc then return end
	if not sbq.checkRPCFinished(rpc, callback, failCallback, 0, ...) then
		if (callback ~= nil or failCallback ~= nil) and name and not sbq.namedRPCList[name] then
			sbq.namedRPCList[name] = {rpc = rpc, callback = callback, failCallback = failCallback, dt = 0, args = {...}}
		end
	end
end


sbq.loopedMessages = {}
function sbq.loopedMessage(name, eid, message, args, callback, failCallback)
	if (type(eid) == "string") or (type(eid) == "number" and world.entityExists(eid)) then
		if sbq.loopedMessages[name] == nil then
			sbq.loopedMessages[name] = {
				rpc = world.sendEntityMessage(eid, message, table.unpack(args or {})),
				callback = callback,
				failCallback = failCallback
			}
		end
		if sbq.checkRPCFinished(sbq.loopedMessages[name].rpc, sbq.loopedMessages[name].callback, sbq.loopedMessages[name].failCallback) then
			sbq.loopedMessages[name] = nil
		end
	elseif failCallback ~= nil then
		failCallback()
	end
end

function sbq.timedLoopedMessage(name, time, eid, message, args, callback, failCallback)
	return sbq.timer(name, time, function ()
		sbq.addRPC(world.sendEntityMessage(eid, message, table.unpack(args or {})), callback, failCallback)
	end)
end

sbq.timerList = {}

function sbq.randomTimer(name, min, max, callback, ...)
	if name == nil or sbq.timerList[name] == nil then
		local timer = {
			targetTime = (math.random(min * 100, max * 100))/100,
			currTime = 0,
			callback = callback,
			args = {...}
		}
		sbq.timerList[name or sb.makeUuid()] = timer
		return true
	end
end

function sbq.timer(name, time, callback, ...)
	if name == nil or sbq.timerList[name] == nil then
		local timer = {
			targetTime = time,
			currTime = 0,
			callback = callback,
			args = {...}
		}
		sbq.timerList[name or sb.makeUuid()] = timer
		return true
	end
end

function sbq.forceTimer(name, time, callback, ...)
	local timer = {
		targetTime = time,
		currTime = 0,
		callback = callback,
		args = {...}
	}
	sbq.timerList[name or sb.makeUuid()] = timer
	return true
end

function sbq.checkTimers(dt)
	for name, timer in pairs(sbq.timerList) do
		if not timer.targetTime then sbq.logInfo(name) end
		timer.currTime = timer.currTime + dt
		if timer.currTime >= timer.targetTime then
			if timer.callback ~= nil then
				timer.callback(table.unpack(timer.args or {}))
			end
			sbq.timerList[name] = nil
		end
	end
end

function sbq.timerRunning(name)
	return (sbq.timerList[name] or {}).currTime
end
