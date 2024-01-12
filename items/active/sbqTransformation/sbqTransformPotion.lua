function init()
	self.vehicle = config.getParameter("vehicle")
	activeItem.setArmAngle(-math.pi/4)
	animator.resetTransformationGroup("potion")
	animator.rotateTransformationGroup("potion", math.pi/4)
end

function update(dt, fireMode, shiftHeld)

	if not self.useTimer and fireMode == "primary" and not activeItem.callOtherHandScript("isDartGun") then
	self.useTimer = 0
	activeItem.setArmAngle(0)
	animator.playSound("drink", 4)
	end

	if self.useTimer then
		self.useTimer = self.useTimer + dt

		if self.useTimer < 3.1 then
			activeItem.setArmAngle(self.useTimer/5)
		elseif self.useTimer < 5.5 then
			activeItem.setArmAngle(math.max(3.1/5 - (self.useTimer-3.1)*3, -math.pi/3))
		else
			local position = mcontroller.position()
			local settings = player.getProperty("sbqSettings") or {}
			local sbqSettings = settings[self.vehicle] or {}
			settings[self.vehicle] = sbqSettings

			animator.playSound("activate")

			settings.selected = self.vehicle
			if settings.types == nil then settings.types = {} end
			local priority = 0
			for _, data in pairs(settings.types) do
				if type(data.index) == "number" and data.index > priority then
					priority = data.index
				end
			end
			local newUnlock
			if not settings.types[self.vehicle] then
				newUnlock = true
				settings.types[self.vehicle] = { enable = true, index = priority + 1 }
			end
			player.setProperty("sbqSettings", settings)

			player.makeTechAvailable("sbqSpawner")
			player.enableTech("sbqSpawner")
			player.equipTech("sbqSpawner")

			local currentData = player.getProperty("sbqCurrentData") or {}

			world.spawnVehicle( self.vehicle, { position[1], position[2] + 1.5 }, { driver = entity.id(), settings = sbqSettings, retrievePrey = currentData.id, scale = mcontroller.scale() } )

			if newUnlock then
				player.radioMessage({
					messageId = self.vehicle.."1", unique = false,
					text = "It seems that the potion you just drank transformed you into "..config.getParameter("transformationDescription")..".\nScans indicate that the ^green;[F]^reset;, ^green;[G]^reset;, and ^green;[H]^reset; buttons may be helpful in this form."
				}, 1)
				player.radioMessage({
					messageId = self.vehicle.."2", unique = false,
					text = "I suggest reading the included guide for more information about how to control your new form.\n^#555;(Information on your transformation can be found in the ^#711;Starbecue Settings^#555; menu from the ^#711;Quickbar^#555;.)"
				}, 5)
			end

			item.consume(1)
		end
	end
end

function dartGunData()
	return { funcName = "vehiclePred", data = self.vehicle }
end
