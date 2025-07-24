local old = {
    build = build or function () end
}
function build(identity, humanoidParameters, humanoidConfig, npcHumanoidConfig)
    if humanoidParameters.sbqEnabled then
        humanoidConfig.useAnimation = true
    end
    humanoidConfig = old.build(identity, humanoidParameters, humanoidConfig, npcHumanoidConfig)
    if not humanoidConfig.useAnimation then return humanoidConfig end

    return humanoidConfig
end
