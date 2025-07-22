local old = {
    init = init or function ()end
}
function init()
    message.setHandler("sbqSetConfigParameter", function(_, _, k, v)
        object.setConfigParameter(k, v)
        if config.getParameter("sbqSetConfigReinit") then old.init() end
    end)
    old.init()
end
