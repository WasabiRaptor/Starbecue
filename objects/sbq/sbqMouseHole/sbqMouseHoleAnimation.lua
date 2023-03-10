
require "/scripts/vec2.lua"
require "/scripts/poly.lua"

local timers = {
	refresh = 5
}
local materials = {}
local colors = {}
local blockImages = {}
local blockViewMasks = {}
local spaces
local detection = {}
local position = {}
local viewOffset = {4,4}

function init()
	script.setUpdateDelta(2)
	position = objectAnimator.position()
	viewOffset = objectAnimator.getParameter("viewOffset") or viewOffset
end

function update()
	spaces = objectAnimator.getParameter("coverSpaces")
	if not spaces then return end
	local rect = poly.boundBox(spaces)
	detection[1] = vec2.add({ rect[1] - 1, rect[2] - 1 }, position)
	detection[2] = vec2.add({ rect[3] + 2, rect[4] + 2 }, position)

	local dt = script.updateDt()
	for i, time in pairs(timers) do
		timers[i] = math.max(0,time-dt)
	end
	if timers.refresh <= 0 then
		timers.refresh = 5
		materials = {}
	end
	playerViewCircle()
	setMaterials()
end

function setMaterials()
	localAnimator.clearDrawables()
	for _, coords in ipairs(spaces or {}) do
		local x = coords[1]
		local y = coords[2]
		local position = vec2.add(position, { x, y })
		local material = world.material(position, "background")
		local fgMat = world.material(position, "foreground")
		local color = world.materialColor(position, "background")
		local part = "block" .. x .. "_" .. y
		if not fgMat then
			if materials["block" .. x .. "_" .. y] ~= material or colors["block" .. x .. "_" .. y] ~= color then
				materials["block" .. x .. "_" .. y] = material
				colors["block" .. x .. "_" .. y] = color
				setMaterial(material, color, position, part)
			end
			localAnimator.addDrawable(
				{
					image = (blockImages[part] or "/empty_image.png") .. (blockViewMasks[part] or ""),
					centered = false,
					position = position
				},
				"ForegroundOverlay+1"
			)
		end
	end
end

local tileCheck = {
	{ { 0, 1 }, "up", },
	{ { 0, -1 }, "down" },
	{ { -1, 0 }, "left.wall", {-1,-1}, "left.floor" },
	{ { 1, 0 }, "right.wall", {1,-1}, "right.floor" },
}
function setMaterial(material, color, tilePosition, part)
	if not material then return end
	local hueshift = world.materialHueShift(tilePosition, "background")
	local materialConfig = root.materialConfig(material)
	if materialConfig then

		local renderTemplate = root.assetJson(materialConfig.config.renderTemplate)
		local tileType = "base"
		local data = renderTemplate.pieces[tileType]
		if not data then return end
		local texture = fixFilepath(materialConfig.config.renderParameters.texture, materialConfig)
		local imageSize = root.imageSize(texture)
		local mask = ""
		local crop1 = vec2.sub({ data.texturePosition[1], imageSize[2] - data.texturePosition[2] - data.textureSize[2] }, vec2.mul(data.colorStride, color))
		local crop2 = vec2.sub({ data.texturePosition[1] + data.textureSize[1], imageSize[2] - data.texturePosition[2] }, vec2.mul(data.colorStride, color))
		for _, check in ipairs(tileCheck) do
			local pos1 = vec2.add(check[1], tilePosition)
			local spaceOccupied
			for _, space in ipairs(spaces) do
				local pos2 = vec2.add(space, position)
				if pos1[1] == pos2[1] and pos1[2] == pos2[2] then
					spaceOccupied = true
					break
				end
				local mat = world.material(pos1, "foreground")
				if mat then
					spaceOccupied = true
				end
			end
			if not spaceOccupied then
				if check[3] then
					local pos3 = vec2.add(check[3], tilePosition)
					local mat = world.material(pos3, "foreground")
					if mat then
						mask = mask.."?addmask=/objects/sbq/sbqMouseHole/sbqMouseHole.png:"..check[4]..";0;0"
					else
						mask = mask.."?addmask=/objects/sbq/sbqMouseHole/sbqMouseHole.png:"..check[2]..";0;0"
					end
				else
					mask = mask.."?addmask=/objects/sbq/sbqMouseHole/sbqMouseHole.png:"..check[2]..";0;0"
				end
			end
		end
		blockImages[part] = sb.replaceTags(
			"<materialImage>?crop=<cropX1>;<cropY1>;<cropX2>;<cropY2>?hueshift=<hueshift><mask>",
			{
				hueshift = hueshift,
				materialImage = texture,
				mask = mask,
				cropX1 = crop1[1],
				cropX2 = crop2[1],
				cropY1 = crop1[2],
				cropY2 = crop2[2]
			}
		)
	end
end

function playerViewCircle()
	local players = world.playerQuery(detection[1], detection[2])
	local masks = {}
	for _, coords in ipairs(spaces or {}) do
		local x = coords[1]
		local y = coords[2]
		masks["block" .. x .. "_" .. y] = ""
	end
	if players and players[1] ~= nil then

		for _, player in ipairs(players) do
			local velocity = world.entityVelocity(player)
			if math.abs(velocity[1]) > 1 or math.abs(velocity[2]) > 1 then
				timers[player] = 5
			end
			if type(timers[player]) == "number" and timers[player] > 0 then
				local distance = vec2.mul(vec2.floor(vec2.mul(vec2.add(entity.distanceToEntity(player), viewOffset), 8)), -1)
				for _, coords in ipairs(spaces or {}) do
					local x = coords[1]
					local y = coords[2]
					local xOffset = (distance[1] + (x * 8))
					local yOffset = (distance[2] + (y * 8))

					if xOffset >= 0 and xOffset <= 48 and yOffset >= 0 and yOffset <= 48 then
						masks["block" .. x .. "_" .. y] = masks["block" .. x .. "_" .. y] ..
							"?addmask="..(objectAnimator.getParameter("viewCircle") or "/objects/sbq/sbqMouseHole/sbqMouseHoleView.png")..";" .. xOffset .. ";" .. yOffset
					end
				end
			end
		end
	end
	blockViewMasks = masks
end

function fixFilepath(string, item)
	if type(string) == "string" then
		if string == "" then return
		elseif string:find("^?") then return
		elseif string:find("^/") then
			return string
		else
			local lastSlash = 1
			local found = item.path:find("/", lastSlash+1)
			while found ~= nil do
				lastSlash = found
				found = item.path:find("/", lastSlash+1)
			end
			return item.path:sub(1,lastSlash)..string
		end
	else
		return
	end
end
