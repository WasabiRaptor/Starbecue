require("/scripts/SBQ_everything_primary.lua")
require("/scripts/SBQ_humanoid.lua")
local old = {
	init = init,
	update = update
}
function init()
    old.init()

	message.setHandler("cleanAnimOverrideScriptItems", function(_,_)
		cleanAnimOverrideScriptItems()
	end)
end

function cleanAnimOverrideScriptItems()
	for i, slot in ipairs({"primary", "alt"}) do
		local item = npc.getItemSlot(slot)
		if item and item.parameters and item.parameters.itemHasOverrideLockScript then
			item.parameters.scripts = nil
			item.parameters.animationScripts = nil
            item.parameters.itemHasOverrideLockScript = nil
			npc.setItemSlot(slot, item)
		end
	end
end
