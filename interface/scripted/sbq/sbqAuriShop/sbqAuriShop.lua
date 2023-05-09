---@diagnostic disable: undefined-global

local buyAmount = 1

local shopRecipes = root.assetJson(metagui.inputData.shopRecipes or "/recipes/auriShop/auriShopRecipes.config")
local catagoryLabels = root.assetJson("/items/categories.config").labels

local buyRecipe

if type(metagui.inputData.dialogueTree.itemSelection) == "string" then
	metagui.inputData.dialogueTree.itemSelection = root.assetJson(metagui.inputData.dialogueTree.itemSelection)
end

require("/interface/scripted/sbq/sbqDialogueBox/sbqDialogueBox.lua")

local lastWasGreeting = true

function fixFilepath(string, item)
	if type(string) == "string" then
		if string == "" then return
		elseif string:find("^?") then return
		elseif string:find("^/") then
			return string
		else
			return item.directory..string
		end
	else
		return
	end
end

for j, tabData in pairs(shopRecipes) do
	local tab = tabData.name
	local recipes = tabData.recipes

	shopTabField:newTab({
		type = "tab", id = tab.."ShopTab", title = tabData.title or "", toolTip = tabData.toolTip, icon = tabData.icon, color = tabData.color or "ff00ff",
		contents = { type = "panel", style = "flat", children = {{align = 0,size = 155},{{ type = "scrollArea", scrollDirections = {0, 1}, scrollBars = true, thumbScrolling = true, children = {
			{ type = "layout", id = tab.."ScrollArea", mode = "vertical", spacing = -3, align = 0, children = {}}
		}}}}}
	})

	local tabScrollArea = _ENV[tab.."ScrollArea"]
	for i, recipe in ipairs(recipes) do
		local resultItemConfig = root.itemConfig({ name = recipe.result, count = recipe.count, parameters = recipe.parameters })
		if resultItemConfig ~= nil then
			local bottom = { { mode = "horizontal" }, { type = "layout", expandMode = { 1, 1 } }, { type = "label", text = "", inline = true, align = 1 } }
			local toolTip = nil
			if not recipe.materials then
				recipe.materials = {
					{ item = "money", count = resultItemConfig.config.price or 1 }
				}
			end
			for _, material in ipairs(recipe.materials) do
				if material.item == "money" then
					table.insert(bottom, { type = "image", file = "/interface/merchant/pixels.png", align = 1 })
					table.insert(bottom, { type = "label", text = (tostring(material.count)), inline = true, align = 1 })
				end
				if material.item == "essence" then
					table.insert(bottom, { type = "image", file = "/interface/scripted/sbq/sbqAuriShop/essence.png", align = 1 })
					table.insert(bottom, { type = "label", text = (tostring(material.count)), inline = true, align = 1 })
				end
				local materialConfig = root.itemConfig(material.item)
				if materialConfig then
					toolTip = (toolTip or "")..materialConfig.config.shortdescription.." ^#555;×"..material.count.."^reset;\n"
				end
			end
			local listItem = tabScrollArea:addChild({ type = "menuItem", selectionGroup = "buyItem", toolTip = toolTip, children = {{ type = "panel", style = "convex", children = {{ mode = "horizontal"},
				{ type = "itemSlot", autoInteract = false, item = { name = recipe.result, count = recipe.count, parameters = recipe.parameters }},
				{
					{ type = "label", text = resultItemConfig.config.shortdescription},
					{
						{ type = "label", text = "^gray;"..(catagoryLabels[resultItemConfig.config.category] or resultItemConfig.config.category), expandMode = {2,1}},
						bottom
					}
				}
			}}}})

			local image = resultItemConfig.config.inventoryIcon or "/empty_image.png"
			local scale = 2
			local wasObject

			local objectImage = (
				((((resultItemConfig.config.orientations or {})[1] or {}).imageLayers or {})[1] or {}).image
				or ((resultItemConfig.config.orientations or {})[1] or {}).image
				or ((resultItemConfig.config.orientations or {})[1] or {}).dualImage
			)
			if objectImage then
				image = objectImage
				wasObject = true
			elseif resultItemConfig.config.largeImage ~= nil then
				image = resultItemConfig.config.largeImage
				scale = 1.5
			end
			---@diagnostic disable-next-line: cast-local-type
			image = fixFilepath(image, resultItemConfig)


			if wasObject and image ~= nil then
				local success, size = pcall(root.imageSize,(image))
				if success and (size[1] > 90 or size[2] > 90) then
					local x = 90/(size[1])
					local y = 90/(size[2])
					if x > y then
						scale = y
					else
						scale = x
					end
				else
					scale = 1
				end
			end

			function listItem:onClick()
				buyRecipe = recipe
				itemInfoPanelSlot:setItem({ name = recipe.result, parameters = recipe.parameters })
				itemNameLabel:setText(resultItemConfig.parameters.shortdescription or resultItemConfig.config.shortdescription)
				itemCategoryLabel:setText("^gray;"..(catagoryLabels[resultItemConfig.config.category] or resultItemConfig.config.category))
				itemDescriptionLabel:setText(resultItemConfig.parameters.description or resultItemConfig.config.description)
				itemImage:setFile(sb.replaceTags(image, { frame = 1, color = resultItemConfig.parameters.color or resultItemConfig.config.color or "default" }))
				itemImage:setScale({scale, scale})

				if sbq.data.dialogueTree.itemSelection[recipe.dialogue or recipe.result] ~= nil then
					lastWasGreeting = false
					sbq.updateDialogueBox(".itemSelection"..(recipe.dialogue or recipe.result))
				elseif not lastWasGreeting then
					sbq.updateDialogueBox( metagui.inputData.dialogueTreeStart or ".greeting" )
				end
			end
		end
	end
end

function decAmount:onClick()
	buyAmount = math.max(1, buyAmount - 1)
	buyAmountLabel:setText(tostring(buyAmount))
end

function incAmount:onClick()
	buyAmount = buyAmount + 1
	buyAmountLabel:setText(tostring(buyAmount))
end

function buy:onClick()
	if hasMaterials() or player.isAdmin() then
		if not player.isAdmin() then
			for _, material in ipairs(buyRecipe.materials) do
				if not player.consumeItem({ name = material.item, count = material.count * buyAmount })then
					player.consumeCurrency( material.item, material.count * buyAmount )
				end
			end
		end
		for i = 1, buyAmount do
			player.giveItem({ name = buyRecipe.result, count = buyRecipe.count, parameters = buyRecipe.parameters })
		end
	else
		pane.playSound("/sfx/interface/clickon_error.ogg")
	end
end

function hasMaterials()
	for _, material in ipairs(buyRecipe.materials) do
		if not ( (material.count * buyAmount) <= player.hasCountOfItem({ name = material.item}) or (material.count * buyAmount) <= player.currency(material.item)) then return false end
	end
	return true
end
