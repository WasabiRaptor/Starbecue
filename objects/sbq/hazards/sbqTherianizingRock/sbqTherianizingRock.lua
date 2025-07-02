local identities = {}
local amount = 1
local lifetime = 1
function init()
    for _, v in ipairs(config.getParameter("identities")) do
        if v.species then
            if root.speciesConfig(v.species) then
                table.insert(identities, v)
            end
        else
            table.insert(identities, v)
        end
    end
    amount = config.getParameter("projectileAmount", 1)
    lifetime = config.getParameter("projectileLifetime", 1)
end

function update(dt)
    local pos = entity.position()
    local identity = identities[math.random(#identities)]
    for i = 1, amount do
        world.spawnProjectile(
            "sbqMessageOnHit",
            { pos[1] + 1, pos[2] + 1 },
            entity.id(),
            { math.random() * (({ 1, -1 })[math.random(1, 2)]), math.random() * (({ 1, -1 })[math.random(1, 2)]) },
            false,
            {
                message = "sbqDoTransformation",
                args = {
                    identity
                },
                timeToLive = lifetime
            }
        )
    end
end
