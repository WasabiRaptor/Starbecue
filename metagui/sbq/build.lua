function init() pane.dismiss()
  _mgcfg = root.assetJson("/panes.config").metaGUI
  if not _mgcfg then -- attempt to use fallback if metaGUI isn't present
    local fb = config.getParameter("fallback")
    if not fb then return player.confirm {
        paneLayout = "/interface/windowconfig/popup.config:paneLayout",
        icon = "/interface/errorpopup/erroricon.png",
        title = "metaGUI error",
        message = "Could not detect metaGUI/StardustLib, and interaction does not specify a fallback."
      } end
    if type(fb) ~= "table" or not fb[1] then fb = { "ScriptPane", fb } end
    player.interact(fb[1], fb[2], pane.sourceEntity())
  else
    -- inject our own scripts
    local player_interact = player.interact
    function player.interact(type, config, source)
        if type == "ScriptPane" then
            table.insert(config.scripts, "/metagui/sbq/custom_widgets.lua")
        end
        player_interact(type, config, source)
    end
    require(_mgcfg.providerRoot .. "build.lua")
  end
end