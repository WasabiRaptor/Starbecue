local didHit = false
function hit(eid)
    didHit = true
    local rpc = world.sendEntityMessage(eid, config.getParameter("message"), table.unpack(config.getParameter("args") or {}))
	if rpc:finished() then
		if not rpc:succeeded() then didHit = false end
	end
end

function uninit()
    if didHit then return end
    local itemName = config.getParameter("itemName")
	if not itemName then return end
	world.spawnItem(itemName, mcontroller.position(), 1, {args = config.getParameter("args")}, mcontroller.velocity())
end
