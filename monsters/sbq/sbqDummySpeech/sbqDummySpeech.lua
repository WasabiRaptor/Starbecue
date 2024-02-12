sbq = {}

require("/scripts/any/SBQ_RPC_handling.lua")

function init()
	sbq.parent = config.getParameter("parent")
	sbq.offset = config.getParameter("offset") or { 0, 0 }
	sbq.timer("despawn", 10, function()
		status.dead = true
		monster.setDropPool(nil)
		status.modifyResource("health", -100)
	end)
	sbq.timer("say", 0, function()
		sbq.say(config.getParameter("sayLine"), config.getParameter("sayTags"), config.getParameter("sayImagePortait"), config.getParameter("sayEmote"), config.getParameter("sayAppendName"))
	end)
end

function update(dt)
	if sbq.parent then
		local pos = world.entityPosition(sbq.parent)
		mcontroller.setPosition({pos[1]+sbq.offset[1],pos[2]+sbq.offset[2]})
	end
	sbq.checkTimers(dt)
end

function sbq.say(string, tags, imagePortrait, emote, appendName)
	if type(string) == "string" and string ~= "" then
		if string:find("<love>") then
			status.addEphemeralEffect("love")
		end
		if string:find("<slowlove>") then
			status.addEphemeralEffect("slowlove")
		end
		if string:find("<confused>") then
			status.addEphemeralEffect("sbqConfused")
		end
		if string:find("<sleepy>") then
			status.addEphemeralEffect("sbqSleepy")
		end
		if string:find("<sad>") then
			status.addEphemeralEffect("sbqSad")
		end
		if string:find("<dontSpeak>") then return end

		string = sb.replaceTags(string, tags)
		if string == "" then return end

		if appendName then
			string = appendName..":\n"..string
		end
		local options = {}
		if type(imagePortrait) == "string" and config.getParameter("sayPortrait") then
			monster.sayPortrait(string, imagePortrait, nil, options)
		else
			monster.say(string, nil, options )
		end
	end
end
