
local oldCommand = command

function command(commandName, clientId, args)
	if commandName == "sbq" then
		--[[
		if args[1] == "unlock" then


		elseif args[1] == "escape" then
			--world.sendEntityMessage(clientId, "sbqEscape") -- I fucking hate this game
			return "attempting to escape..."
		else
			return "...what are you doing?"
		end
		]]
		return "what the absolute fuck starbound, why the fuck did you let us make console commands but not fucking give us access to literally any of the tables needed to effect the world, this is fucking useless"
	else
		if oldCommand then return oldCommand(commandName, clientId, args) end
	end
end
