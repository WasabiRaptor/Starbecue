require "/scripts/rect.lua"
require "/scripts/poly.lua"
sbq= {}
require "/scripts/any/SBQ_RPC_handling.lua"

local fade = 255
local fading = false
local checkRects = {}
function init()
	for _, v in ipairs(config.getParameter("checkRects")) do
		table.insert(checkRects, rect.translate(v, object.position()))
	end
end
function update(dt)
	if world.pointTileCollision(entity.position(), { "Null" }) then return end

	sbq.checkTimers(dt)
	if sbq.timer("check",1) then
		fading = false
		for _, v in ipairs(checkRects) do
			local entities = world.playerQuery(rect.ll(v), rect.ur(v))
			-- world.debugPoly({rect.ll(v),rect.lr(v),rect.ur(v),rect.ul(v)},{255,255,0})
			if entities and entities[1] then fading = true break end
		end
	end
	if fading then
		fade = math.max(fade-(255*dt*2),0)
	else
		fade = math.min(fade+(255*dt*2),255)
	end
	animator.setGlobalTag("fg_fade", "?multiply=FFFFFF"..string.format("%02x", math.floor(fade)))

end
