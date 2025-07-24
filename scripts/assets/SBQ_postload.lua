




for _, config in ipairs(assets.byExtension("monstertype")) do
    assets.patch(config, "/scripts/monster/SBQ_monster_patch.lua")
end

for _, config in ipairs(assets.byExtension("npctype")) do
    assets.patch(config, "/scripts/monster/SBQ_npc_patch.lua")
end

for _, config in ipairs(assets.byExtension("species")) do
    assets.patch(config, "/scripts/humanoid/SBQ_species_patch.lua")
end
