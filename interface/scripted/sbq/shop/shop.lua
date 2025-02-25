
local buyAmount = 1
local catagoryLabels = root.assetJson("/items/categories.config").labels
local buyRecipe
shop = {}
function init()
	if type(sbq.shopRecipes) == "string" then
		sbq.shopRecipes = root.assetJson(sbq.shopRecipes)
	end
	if not sbq.dialogueTree then
		_ENV.dialogueLayout:setVisible(false)
	end

	for j, tabData in pairs(sbq.shopRecipes or {}) do
		local tab = tabData.name
		local recipes = tabData.recipes

		_ENV.shopTabField:newTab({
			type = "tab", id = tab.."ShopTab", title = tabData.title or "", toolTip = tabData.toolTip, icon = tabData.icon, color = tabData.color or "ff00ff",
			contents = { type = "panel", style = "flat", children = {{align = 0, expandMode = {2,2}},{{ type = "scrollArea", scrollDirections = {0, 1}, scrollBars = true, thumbScrolling = true, children = {
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
						{ item = "money", count = math.floor(resultItemConfig.config.price or 1) }
					}
				end
				for _, material in ipairs(recipe.materials) do
					local count = tostring(math.floor(material.count))
					if material.item == "money" then
						table.insert(bottom, { type = "image", file = "/interface/merchant/pixels.png", align = 1 })
						table.insert(bottom, { type = "label", text = count, inline = true, align = 1 })
					end
					if material.item == "essence" then
						table.insert(bottom, { type = "image", file = "/interface/scripted/sbq/shop/essence.png", align = 1 })
						table.insert(bottom, { type = "label", text = count, inline = true, align = 1 })
					end
					local materialConfig = root.itemConfig(material.item)
					if materialConfig then
						toolTip = (toolTip or "")..materialConfig.config.shortdescription.." ^#555;×"..count.."^reset;\n"
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

				function listItem:onClick()
					buyRecipe = recipe
					_ENV.itemInfoPanelSlot:setItem({ name = recipe.result, parameters = recipe.parameters })
					_ENV.itemNameLabel:setText(resultItemConfig.parameters.shortdescription or resultItemConfig.config.shortdescription)
					_ENV.itemCategoryLabel:setText("^gray;"..(catagoryLabels[resultItemConfig.config.category] or resultItemConfig.config.category))
					_ENV.itemDescriptionLabel:setText(resultItemConfig.parameters.description or resultItemConfig.config.description)


					if not dialogueProcessor.getDialogue(".itemSelection."..(recipe.dialogue or recipe.result)) then
						dialogueProcessor.getDialogue(".converseShop" )
					end
					dialogueBox.refresh()
				end
			end
		end
	end
end

function _ENV.buyAmountLabel:onTextChanged()
	local v = tonumber(self.text)
	if type(v) == "number" then
		buyAmount = math.floor(v)
	end
end

function _ENV.decAmount:onClick()
	buyAmount = math.max(1, buyAmount - 1)
	_ENV.buyAmountLabel:setText(tostring(buyAmount))
end

function _ENV.incAmount:onClick()
	buyAmount = buyAmount + 1
	_ENV.buyAmountLabel:setText(tostring(buyAmount))
end

function _ENV.buy:onClick()
	if shop.hasMaterials() or player.isAdmin() then
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
		dialogueBox.refresh( ".buy", dialogue.prev, sbq.dialogueTree)
	else
		dialogueBox.refresh( ".buyFail", dialogue.prev, sbq.dialogueTree)
		sbq.playErrorSound()
	end
end

function shop.hasMaterials()
	for _, material in ipairs(buyRecipe.materials) do
		if not ( (material.count * buyAmount) <= player.hasCountOfItem(material, true) or (material.count * buyAmount) <= player.currency(material.item)) then return false end
	end
	return true
end
