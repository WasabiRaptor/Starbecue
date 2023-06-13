
function init()
	effect.addStatModifierGroup({
		{stat = "protection", amount = 100},
		{stat = "invulnerable", amount = 1},
		{stat = "fireStatusImmunity", amount = 1},
		{stat = "iceStatusImmunity", amount = 1},
		{stat = "electricStatusImmunity", amount = 1},
		{stat = "poisonStatusImmunity", amount = 1},
		{stat = "specialStatusImmunity", amount = 1},
		{stat = "breathProtection", amount = 1},
		{stat = "biomecoldImmunity", amount = 1},
		{stat = "biomeheatImmunity", amount = 1},
		{stat = "biomeradiationImmunity", amount = 1},
		{stat = "lavaImmunity", amount = 1},
		{stat = "fallDamageMultiplier", effectiveMultiplier = 0},
		{stat = "foodDelta", effectiveMultiplier = 0 },
		--FU
		{stat = "pusImmunity", amount = 1},
		{stat = "beestingImmunity", amount = 1},
		{stat = "biooozeImmunity", amount = 1},
		{stat = "liquidnitrogenImmunity", amount = 1},
		{stat = "radiationburnImmunity", amount = 1},
		{stat = "sulphuricImmunity", amount = 1},
		{stat = "shadowImmunity", amount = 1},
		{stat = "insanityImmunity", amount = 1},
		{stat = "bleedingImmunity", amount = 1},
		{stat = "pandorasboxglitchtopglitchedImmunity", amount = 1},
	})
	script.setUpdateDelta(0)
end

function update(dt)
end

function uninit()
end
