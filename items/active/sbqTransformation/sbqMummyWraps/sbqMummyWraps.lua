function init()
	self.vehicle = config.getParameter("vehicle")
	activeItem.setArmAngle(-math.pi/4)
end

function update(dt, fireMode, shiftHeld)

	if not self.useTimer and fireMode == "primary" and not activeItem.callOtherHandScript("isDartGun") then
	self.useTimer = 0
	activeItem.setArmAngle(0)
	end

	if self.useTimer then
		self.useTimer = self.useTimer + dt

		if self.useTimer < 0.5 then
			animator.setGlobalTag("consumable", "/empty_image.png")
		elseif self.useTimer > 1 and self.useTimer < 2 then
			activeItem.setArmAngle(-math.pi/4)
		elseif self.useTimer < 3 then

		else
			local position = mcontroller.position()
			local settings = player.getProperty("sbqSettings") or {}
			local sbqSettings = settings[self.vehicle] or {}
			settings[self.vehicle] = sbqSettings


			settings.selected = self.vehicle
			if settings.types == nil then settings.types = {} end

			local priority = 0
			for _, data in pairs(settings.types) do
				if type(data.index) == "number" and data.index > priority then
					priority = data.index
				end
			end
			if not settings.types[self.vehicle] then
				settings.types[self.vehicle] = { enable = true, index = priority + 1 }
			end

			player.setProperty("sbqSettings", settings)

			local currentData = player.getProperty("sbqCurrentData") or {}

			world.spawnVehicle( self.vehicle, { position[1], position[2] + 1.5 }, { driver = entity.id(), settings = sbqSettings, retrievePrey = currentData.id, scale = mcontroller.scale() } )

			item.consume(1)
		end
	end
end
