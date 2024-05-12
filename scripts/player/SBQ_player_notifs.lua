function sbq.notifyPlayer()
	player.setUniverseFlag("foodhall_auriShop")
	if not (root.modMetadata("Stardust Core") or root.modMetadata("StardustLib") or root.modMetadata("QuickbarMini") or root.modMetadata("Stardust Core Lite")) then
		player.confirm({
			paneLayout = "/interface/windowconfig/popup.config:paneLayout",
			icon = "/interface/errorpopup/erroricon.png",
			title = "Starbecue Mod Requirement Warning",
			message = "Stardust Core or Stardust Lite missing.\n \nMake sure to read install information."
		})
	end
	if (not root.assetExists("/stats/monster_compat_list.config")) and not player.getProperty("sbqMonsterCoreLoaderWarned") then
		player.setProperty("sbqMonsterCoreLoaderWarned", true)
		player.confirm({
			paneLayout = "/interface/windowconfig/popup.config:paneLayout",
			icon = "/interface/errorpopup/erroricon.png",
			title = "Starbecue Mod Requirement Warning",
			message = "Monster Core Loader missing.\n \nThis is not required, but without it you may find some mod incompatibilities, especially with FU.\n \nMake sure to read install information."
		})
	end
	if root.itemConfig("spovpilldonut") ~= nil then
		player.confirm({
			paneLayout = "/interface/windowconfig/popup.config:paneLayout",
			icon = "/interface/errorpopup/erroricon.png",
			title = "Starbecue Mod Conflict Warning",
			message = "Zygan SSVM Addons detected.\n \nThat mod is an older version of Starbecue before it was renamed, please remove it."
		})
	end
	local version = root.version()
	local metadata = root.modMetadata("Starbecue")
	if (version.sbq ~= metadata.intendedVersion) then
		player.confirm({
			paneLayout = "/interface/windowconfig/popup.config:paneLayout",
			icon = "/interface/errorpopup/erroricon.png",
			title = "Incorrect Installation",
			message = string.format("Current install is engine ^yellow;v%s^reset;\n \nThis version of SBQ was intended for engine ^green;v%s^reset;\n \nPlease read the install instructions in README.md", version.sbq, metadata.designedEngineVersion)
		})
	end
	if player.introComplete() then
		if (player.getProperty("sbqSettingsVersion") ~= metadata.version) or not player.getProperty("sbqAgreedTerms") then
			player.interact("ScriptPane", { gui = { }, scripts = {"/metagui/sbq/build.lua"}, ui = "starbecue:quickSettings" })
		end
	end
end
