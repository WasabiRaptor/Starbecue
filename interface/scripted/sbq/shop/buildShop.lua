cfg = root.assetJson("/interface/scripted/sbq/shop/shop.ui")

local dialogueBoxUi = root.assetJson("/interface/scripted/sbq/dialogueBox/dialogueBox.ui")
local function assetPath(path, directory)
	if string.sub(path, 1, 1) == "/" then
		return path
	else
		return (directory or "/") .. path
	end
end

for _, v in ipairs(dialogueBoxUi.scripts) do
	table.insert(cfg.scripts, assetPath(v, "/interface/scripted/sbq/dialogueBox/"))
end

table.insert(cfg.children, {
	type = "layout",
	size = dialogueBoxUi.size,
	id = "dialogueLayout",
	mode = "horizontal",
	expandMode = { 1, 0 },
	children = dialogueBoxUi.children,
})
