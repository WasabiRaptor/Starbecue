
require("/vehicles/sbq/sbq_main.lua")

state = {
	smol = {}
}

-------------------------------------------------------------------------------

local _initAfterInit = sbq.initAfterInit
function sbq.initAfterInit()
	_initAfterInit()
	sbq.occupants.total = 0
	if not sbq.eat({force = true, id = sbq.driver, size = config.getParameter("eggSize") or 1}, "eggify", "egg") then
		vehicle.destroy()
	end
	if sbq.settings.skinNames.head == "plastic" or sbq.settings.occupantVisible then
		sbq.occupant[0].visible = true
	else
		sbq.occupant[0].visible = false
	end
end

function sbq.applyStatusLists()
	for i = 0, sbq.occupantSlots do
		if type(sbq.occupant[i].id) == "number" and world.entityExists(sbq.occupant[i].id) then
			if not sbq.weirdFixFrame then
				vehicle.setLoungeEnabled(sbq.occupant[i].seatname, true)
			end
			sbq.loopedMessage( sbq.occupant[i].seatname.."StatusEffects", sbq.occupant[i].id, "sbqApplyStatusEffects", {sbq.occupant[i].statList} )
			if not (i == 0 and sbq.isNested) then
				sbq.loopedMessage( sbq.occupant[i].seatname.."ForceSeat", sbq.occupant[i].id, "sbqForceSit", {{index=i, source=entity.id()}})
			end
		else
			vehicle.setLoungeEnabled(sbq.occupant[i].seatname, false)
		end
	end
	sbq.weirdFixFrame = nil
end

local _openPreyHud = sbq.openPreyHud
function sbq.openPreyHud(i, directions, progressbarDx, icon, location)
	if not (i == 0 and sbq.isNested) then
		_openPreyHud(i, directions, progressbarDx, icon, location)
	end
end

_escapeScript = sbq.escapeScript

function sbq.escapeScript(i)
	if i == 0 then
		sbq.settings.cracks = 1000
		state.smol.crack({id = sbq.driver})
	else
		_escapeScript(i)
	end
end

function sbq.init()
	sbq.startSlot = 0
	sbq.driving = false
	sbq.seats.occupantD = sbq.clearOccupant("D")
	sbq.driverSeat = "occupantD"

	if not sbq.settings.cracks then
		sbq.settings.cracks = 0
	end

	if sbq.settings.impossibleEscape then
		sbq.settings.impossibleEscape = false
	end

	if sbq.settings.skinNames.head == "plastic" then
		if not sbq.settings.firstLoadDone then
			-- get random directives for anyone thats not an avian
			for i = 1, #sbq.sbqData.replaceColors do
				sbq.settings.replaceColorTable[i] = sbq.sbqData.plasticReplaceColors[i][ (math.random( #sbq.sbqData.plasticReplaceColors[i]))]
			end
			sbq.settings.firstLoadDone = true
			sbq.setColorReplaceDirectives()
		end
		animator.setSoundPool("crack", {"/sfx/npc/enemydeathpuff.ogg"})
		sbq.settings.cracks = 3
		sbq.stateconfig.smol.struggle.egg.directions = {
			front = { victimAnimation = "s_front" },
			back = { victimAnimation = "s_back" },
			up = { chances = { min = 1, max = 1}, transition = "crack", victimAnimation = "s_back", indicate = "red" }
		}
		_onDeath = sbq.onDeath
		function sbq.onDeath(eaten)
			if not eaten then
				local item = { name = "sbqPlasticEgg", parameters = { scriptStorage = { settings = sbq.settings } } }
				world.spawnItem(item, mcontroller.position() )
			end
			_onDeath(eaten)
		end
	end

	sbq.setPartTag( "global", "cracks", sbq.settings.cracks )
end

-- don't want warp effects on this ever
function sbq.warpInEffect() end
function sbq.warpOutEffect() end

function sbq.update(dt)
	if sbq.queueDeath and sbq.occupants.total == 0 then
		local skinNames = sbq.settings.skinNames or {}
		local skin = skinNames.head or "default"
		local shard = ((sbq.sbqData.skinEggShards[skin] or {}).mask or "?addmask=/vehicles/sbq/sbqEgg/skins/shards.png")..":"
		local flip = ""
		local blend = "?blendmult=/vehicles/sbq/sbqEgg/skins/"..skin.."/smol/smol_body.png:3.idle.1?addmask=/vehicles/sbq/sbqEgg/skins/"..skin.."/smol/smol_body.png:3.idle.1;0;0"
		if sbq.direction < 0 then
			flip = "?flipx"
		end
		local shardPath = (sbq.sbqData.skinEggShards[skin] or {}).image
		local fast = 1
		if sbq.settings.cracks >= 100 then
			fast = 10
			world.spawnProjectile("sbqMemeExplosion", mcontroller.position())
		end
		if shardPath then
			for i = 1, 10 do
				world.spawnProjectile( "sbqEggShard", mcontroller.position(), entity.id(), {(math.random(-1,1) * math.random()), math.random()}, false, {
					processing = "?blendmult="..shardPath..":"..tostring(i).."?addmask="..shardPath..":"..tostring(i)..";0;0"..sbq.settings.directives..flip,
					timeToLive = math.random(1,3) + math.random(),
					speed = (math.random(5,10) + math.random()) * fast
				})
			end
		else
			for i = 1, 10 do
				world.spawnProjectile( "sbqEggShard", mcontroller.position(), entity.id(), {(math.random(-1,1) * math.random()), math.random()}, false, {
					processing = blend..sbq.settings.directives..shard..tostring(i)..flip,
					timeToLive = math.random(1,3) + math.random(),
					speed = (math.random(5,10) + math.random()) * fast
				})
			end
		end
		sbq.onDeath()
	end
end
-------------------------------------------------------------------------------

function state.smol.crack( args )
	sbq.settings.cracks = sbq.settings.cracks + 1
	animator.playSound("crack")
	if math.random(1, 1000) == 1000 then
		sbq.settings.cracks = 1000
	end

	if sbq.settings.cracks > 3 then
		sbq.uneat(args.id)
		sbq.queueDeath = true
	else sbq.setPartTag( "global", "cracks", sbq.settings.cracks )
		sbq.doAnim("bodyState", "s_"..args.direction)
	end
end


-------------------------------------------------------------------------------
