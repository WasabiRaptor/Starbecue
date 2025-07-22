local parameters = {}
local baseParameters = {}
local parameterPath = {}
function init()
    for _, v in ipairs(world.getObjectParameter(pane.sourceEntity(), "sbqGenericConfigParameters")) do
        baseParameters[v.path[1]] = world.getObjectParameter(pane.sourceEntity(), v.path[1])
        local base = sbq.query(baseParameters, v.path)
        sbq.setPath(parameters, v.path, base)
        parameterPath[v.id] = v.path
    end
end

function sbq.widgetScripts.setParameter(value, setting)
    sb.logInfo(value)
    local path = parameterPath[setting]
    sbq.setPath(parameters, path, value)
    world.sendEntityMessage(pane.sourceEntity(), "sbqSetConfigParameter", path[1], parameters[path[1]])
end
