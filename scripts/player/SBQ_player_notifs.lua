function sbq.notifyPlayer()
    player.setUniverseFlag("foodhall_auriShop")
    -- I should probably do this detection somewhere else and put the notifs on the title screen I think


    -- if not (root.assetSourceMetadata("Stardust Core") or root.assetSourceMetadata("StardustLib") or root.assetSourceMetadata("QuickbarMini") or root.assetSourceMetadata("Stardust Core Lite")) then
    --     player.confirm({
    --         paneLayout = "/interface/windowconfig/popup.config:paneLayout",
    --         icon = "/interface/errorpopup/erroricon.png",
    --         title = "Starbecue Mod Requirement Warning",
    --         message = "Stardust Core or Stardust Lite missing.\n \nMake sure to read install information."
    --     })
    -- end
	-- -- if (not root.assetOrigin("/stats/monster_compat_list.config")) and not player.getProperty("sbqMonsterCoreLoaderWarned") then
	-- -- 	player.setProperty("sbqMonsterCoreLoaderWarned", true)
	-- -- 	player.confirm({
	-- -- 		paneLayout = "/interface/windowconfig/popup.config:paneLayout",
	-- -- 		icon = "/interface/errorpopup/erroricon.png",
	-- -- 		title = "Starbecue Mod Requirement Warning",
	-- -- 		message = "Monster Core Loader missing.\n \nThis is not required, but without it you may find some mod incompatibilities, especially with FU.\n \nMake sure to read install information."
	-- -- 	})
	-- -- end
	-- if root.itemConfig("spovpilldonut") ~= nil then
	-- 	player.confirm({
	-- 		paneLayout = "/interface/windowconfig/popup.config:paneLayout",
	-- 		icon = "/interface/errorpopup/erroricon.png",
	-- 		title = "Starbecue Mod Conflict Warning",
	-- 		message = "Zygan SSVM Addons detected.\n \nThat mod is an older version of Starbecue before it was renamed, please remove it."
	-- 	})
	-- end
	-- local version = {
	-- 	sbq = "?",
	-- 	star = "?",
	-- 	source = "?",
	-- 	architecture = "?"
	-- }
	-- if root.version then
	-- 	version = root.version()
	-- end
	-- local metadata = root.assetSourceMetadata("Starbecue")
	-- if (version.sbq ~= metadata.intendedVersion) then
	-- 	player.confirm({
	-- 		paneLayout = "/interface/windowconfig/popup.config:paneLayout",
	-- 		icon = "/interface/errorpopup/erroricon.png",
	-- 		title = "Incorrect Installation",
	-- 		message = string.format("Current install is engine ^yellow;v%s^reset;\n \nThis version of SBQ was intended for engine ^green;v%s^reset;\n \nPlease read the install instructions in README.md", version.sbq, metadata.intendedVersion)
	-- 	})
	-- end
	if player.introComplete() then
		if (player.getProperty("sbqSettingsVersion") ~= root.assetSourceMetadata(root.assetOrigin("/sbq.config")).version) or not player.getProperty("sbqAgreedTerms") then
			player.interact("ScriptPane", { gui = { }, scripts = {"/metagui/sbq/build.lua"}, ui = "starbecue:quickSettings" })
		end
	end
end
