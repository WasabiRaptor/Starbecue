local identities
function init()
    identities = config.getParameter("identities")
end
function update(dt)
    local pos = entity.position()
    world.spawnProjectile(
        "sbqMessageOnHit",
        {pos[1]+1,pos[2]+1},
        entity.id(),
        { math.random() * (({ 1, -1 })[math.random(1, 2)]), math.random() * (({ 1, -1 })[math.random(1, 2)]) },
        false,
        {
            message = "sbqDoTransformation",
            args = {
                identities[math.random(#identities)]
            }
        }
    )
end
