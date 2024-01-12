sbq = {}
require("/scripts/SBQ_RPC_handling.lua")
function init()
	sbq.config = root.assetJson("/sbqGeneral.config")
end
local inited
local source
function update(dt)
	sbq.checkRPCsFinished(dt)
	if not inited then
		source = status.statusProperty("sbqProjectileSource")
		if (type(source) == "number") and world.entityExists(source) and (status.statusProperty("sbqType") ~= "prey") then
			status.setStatusProperty("sbqProjectileSource", nil)
			inited = true
			sbq.addRPC(world.sendEntityMessage(source, "sbqPotionDartGunData"), function (gotData)
				if gotData then
					if sbq[gotData.funcName] ~= nil then
						sbq[gotData.funcName](gotData.data)
					end
				end

			end, function ()
				effect.expire()
			end)
		elseif status.statusProperty("sbqType") == "prey" then
			effect.expire()
		end
	end
end

function uninit()
end

function sbq.transform(data)
	local allow = getPreyEnabled().transformAllow
	if not allow then return effect.expire() end

	world.sendEntityMessage(entity.id(), "sbqMysteriousPotionTF", data, 5*60)
	world.spawnProjectile("sbqWarpInEffect", mcontroller.position(), entity.id(), { 0, 0 }, true)
	animator.playSound("activate")
end

function sbq.genderswap()
	local allowed = getPreyEnabled().genderswapAllow
	if (not allowed) or (not type(humanoid) == "table") then return effect.expire() end

	local table = {
		male = "female",
		female = "male"
	}
	data = humanoid.getIdentity()
	data.gender = table[data.gender]
    humanoid.setIdentity(data)

	world.spawnProjectile("sbqWarpInEffect", mcontroller.position(), entity.id(), { 0, 0 }, true)
	animator.playSound("activate")
end

function sbq.reversion()
	local allow = getPreyEnabled().transformAllow
	if not allow then return effect.expire() end

	world.sendEntityMessage(entity.id(), "sbqEndMysteriousPotionTF")
	animator.playSound("activate")
end

function sbq.vehiclePred(vehicle)
	local allow = getPreyEnabled().transformAllow
	if not allow then return effect.expire() end

	local currentData = status.statusProperty("sbqCurrentData") or {}
	sbq.addRPC(world.sendEntityMessage(entity.id(), "sbqLoadSettings", vehicle), function (settings)
		world.spawnVehicle( vehicle, mcontroller.position(), { driver = entity.id(), settings = settings, retrievePrey = currentData.id, scale = mcontroller.scale() } )
		animator.playSound("activate")
	end, function ()
		world.spawnVehicle( vehicle, mcontroller.position(), { driver = entity.id(), retrievePrey = currentData.id, scale = mcontroller.scale() } )
		animator.playSound("activate")
	end)
end

function getPreyEnabled()
	return sb.jsonMerge(root.assetJson("/sbqGeneral.config:defaultPreyEnabled")[world.entityType(entity.id())], sb.jsonMerge((status.statusProperty("sbqPreyEnabled") or {}), (status.statusProperty("sbqOverridePreyEnabled")or {})))
end
