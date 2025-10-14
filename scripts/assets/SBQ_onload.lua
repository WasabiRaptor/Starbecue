local races = {
	"sbq/DreccanOfPaws/Dreccan"
}
local charcreation_patch = {}
local universe_server_patch = {}
local ai_patch = {}
local player_patch = {}
local quests_patch = {}
for _, species in ipairs(races) do
	local speciesConfig = assets.json("/species/" .. species .. ".species")
	table.insert(charcreation_patch, { op = "add", path = "/speciesOrdering/-", value = species })
	universe_server_patch = sb.jsonMerge(universe_server_patch, {
		speciesShips = {
			[species] = speciesConfig.ships or {
				"/ships/novakid/novakidt0.structure",
				"/ships/novakid/novakidt1.structure",
				"/ships/novakid/novakidt2.structure",
				"/ships/novakid/novakidt3.structure",
				"/ships/novakid/novakidt4.structure",
				"/ships/novakid/novakidt5.structure",
				"/ships/novakid/novakidt6.structure",
				"/ships/novakid/novakidt7.structure",
				"/ships/novakid/novakidt8.structure"
			}
		}
	})
	if not assets.exists("/objects/protectorate/objects/protectorateship/protectorateship" .. species .. ".png") then
		assets.add("/objects/protectorate/objects/protectorateship/protectorateship" .. species .. ".png",
			assets.image("/objects/protectorate/objects/protectorateship/protectorateshipnovakid.png"))
	end
	if not assets.exists("/cinematics/story/smallship/" .. species .. "ship.png") then
		assets.add("/cinematics/story/smallship/" .. species .. "ship.png",
			assets.image("/cinematics/story/smallship/novakidship.png"))
	end
	if not assets.exists("/cinematics/story/smallship/" .. species .. "ship4.png") then
		assets.add("/cinematics/story/smallship/" .. species .. "ship4.png",
			assets.image("/cinematics/story/smallship/novakidship4.png"))
	end
	if not assets.exists("/cinematics/story/smallship/" .. species .. "ship3.png") then
		assets.add("/cinematics/story/smallship/" .. species .. "ship3.png",
			assets.image("/cinematics/story/smallship/novakidship3.png"))
	end
	if not assets.exists("/cinematics/story/smallship/" .. species .. "ship2.png") then
		assets.add("/cinematics/story/smallship/" .. species .. "ship2.png",
			assets.image("/cinematics/story/smallship/novakidship2.png"))
	end


	local ai = speciesConfig.ai or {
		aiFrames = "NovakidAI.png",
		portraitFrames = "portraits/novakidportrait.png",
		staticFrames = "staticGlitch.png"
	}
	ai_patch = sb.jsonMerge(ai_patch, {
		species = {
			[species] = ai
		}
	})
	if not assets.exists("/ai/portraits/" .. species .. "portrait.png") then
		assets.add("/ai/portraits/" .. species .. "portrait.png",
			assets.image("/ai/"..ai.portraitFrames))
	end

	player_patch = sb.jsonMerge(player_patch, {
		defaultCodexes = {
			[species] = speciesConfig.defaultCodexes or { "protectorate1", "protectorate2" }
		}
	})
	quests_patch = sb.jsonMerge(quests_patch, {
		initialquests = {
			[species] = speciesConfig.initialquests or { "protectorate" }
		}
	})

	if not assets.exists("/cinematics/teleport/deploy_" .. species .. ".cinematic") then
		assets.add("/cinematics/teleport/deploy_" .. species .. ".cinematic",
			assets.bytes(speciesConfig.deployCinematic or "/cinematics/teleport/deploy_sbq/template.cinematic"):gsub(
				"%<species%>", species):gsub("%<effectDirectives%>", speciesConfig.effectDirectives))
	end
	if not assets.exists("/cinematics/teleport/teleport_" .. species .. ".cinematic") then
		assets.add("/cinematics/teleport/teleport_" .. species .. ".cinematic",
			assets.bytes(speciesConfig.teleportCinematic or "/cinematics/teleport/teleport_sbq/template.cinematic"):gsub(
				"%<species%>", species):gsub("%<effectDirectives%>", speciesConfig.effectDirectives))
	end
	if not assets.exists("/cinematics/respawn/" .. species .. "/respawncasual.cinematic") then
		assets.add("/cinematics/respawn/" .. species .. "/respawncasual.cinematic",
			assets.bytes(speciesConfig.teleportCinematic or "/cinematics/respawn/sbq/template/respawncasual.cinematic")
			:gsub("%<species%>", species):gsub("%<effectDirectives%>", speciesConfig.effectDirectives))
	end
	if not assets.exists("/cinematics/respawn/" .. species .. "/respawnsurvival.cinematic") then
		assets.add("/cinematics/respawn/" .. species .. "/respawnsurvival.cinematic",
			assets.bytes(speciesConfig.teleportCinematic or "/cinematics/respawn/sbq/template/respawnsurvival.cinematic")
			:gsub("%<species%>", species):gsub("%<effectDirectives%>", speciesConfig.effectDirectives))
	end

	if not assets.exists("/interface/ai/suits/" .. species .. "-female.png") then
		assets.add("/interface/ai/suits/" .. species .. "-female.png",
			assets.image("/interface/ai/suits/sbq/template-female.png"))
	end
	if not assets.exists("/interface/ai/suits/" .. species .. "-male.png") then
		assets.add("/interface/ai/suits/" .. species .. "-male.png",
			assets.image("/interface/ai/suits/sbq/template-male.png"))
	end

	if not assets.exists("/interface/scripted/techupgrade/suits/" .. species .. "-female.png") then
		assets.add("/interface/scripted/techupgrade/suits/" .. species .. "-female.png",
			assets.image("/interface/scripted/techupgrade/suits/sbq/template-female.png"))
	end
	if not assets.exists("/interface/scripted/techupgrade/suits/" .. species .. "-female-body.png") then
		assets.add("/interface/scripted/techupgrade/suits/" .. species .. "-female-body.png",
			assets.image("/interface/scripted/techupgrade/suits/sbq/template-female-body.png"))
	end
	if not assets.exists("/interface/scripted/techupgrade/suits/" .. species .. "-female-head.png") then
		assets.add("/interface/scripted/techupgrade/suits/" .. species .. "-female-head.png",
			assets.image("/interface/scripted/techupgrade/suits/sbq/template-female-head.png"))
	end
	if not assets.exists("/interface/scripted/techupgrade/suits/" .. species .. "-female-legs.png") then
		assets.add("/interface/scripted/techupgrade/suits/" .. species .. "-female-legs.png",
			assets.image("/interface/scripted/techupgrade/suits/sbq/template-female-legs.png"))
	end

	if not assets.exists("/interface/scripted/techupgrade/suits/" .. species .. "-male.png") then
		assets.add("/interface/scripted/techupgrade/suits/" .. species .. "-male.png",
			assets.image("/interface/scripted/techupgrade/suits/sbq/template-male.png"))
	end
	if not assets.exists("/interface/scripted/techupgrade/suits/" .. species .. "-male-body.png") then
		assets.add("/interface/scripted/techupgrade/suits/" .. species .. "-male-body.png",
			assets.image("/interface/scripted/techupgrade/suits/sbq/template-male-body.png"))
	end
	if not assets.exists("/interface/scripted/techupgrade/suits/" .. species .. "-male-head.png") then
		assets.add("/interface/scripted/techupgrade/suits/" .. species .. "-male-head.png",
			assets.image("/interface/scripted/techupgrade/suits/sbq/template-male-head.png"))
	end
	if not assets.exists("/interface/scripted/techupgrade/suits/" .. species .. "-male-legs.png") then
		assets.add("/interface/scripted/techupgrade/suits/" .. species .. "-male-legs.png",
			assets.image("/interface/scripted/techupgrade/suits/sbq/template-male-legs.png"))
	end

	if not assets.exists("/ai/portraits/" .. species .. "questportrait.png") then
		assets.add("/ai/portraits/" .. species .. "questportrait.png",
			assets.image("/ai/portraits/novakidquestportrait.png"))
	end
end

assets.add("/interface/windowconfig/charcreation.config.patch", sb.printJson(charcreation_patch))
assets.add("/universe_server.config.patch", sb.printJson(universe_server_patch))
assets.add("/ai/ai.config.patch", sb.printJson(ai_patch))
assets.add("/player.config.patch", sb.printJson(player_patch))
assets.add("/quests/quests.config.patch", sb.printJson(quests_patch))
