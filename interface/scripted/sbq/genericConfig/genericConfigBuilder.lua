sbq = {}
require("/scripts/any/SBQ_util.lua")
cfg = root.assetJson("/interface/scripted/sbq/genericConfig/genericConfig.ui")
cfg.size = world.getObjectParameter(pane.sourceEntity(), "sbqGenericConfigSize") or cfg.size
cfg.icon = world.getObjectParameter(pane.sourceEntity(), "sbqGenericConfigIcon") or cfg.icon
cfg.title = sbq.getString(world.getObjectParameter(pane.sourceEntity(), "sbqGenericConfigTitle") or cfg.title)
local baseParameters = {}
for _, v in ipairs(world.getObjectParameter(pane.sourceEntity(), "sbqGenericConfigParameters")) do
    baseParameters[v.path[1]] = world.getObjectParameter(pane.sourceEntity(), v.path[1])
    local base = sbq.query(baseParameters, v.path)
    local widget = { type = "layout", id = v.id.."Layout", expandMode = {1,0}, mode = "horizontal", children = {
        {
            settingType = type(base),
            id = v.id,
            type = "sbqTextBox",
            toolTip = v.toolTip,
            script = "setParameter",
            text = tostring(base)
        },
        { type = "label", id = v.id.."Label", text = v.label, width = v.labelWidth}
    }}
    table.insert(cfg.children, widget)
end
