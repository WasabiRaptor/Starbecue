

-- this is meant to add the extra colors to the palette that Familiar need
function patch(config)
	for i = 1, #config.hairColor do
		local replacements = config.hairColor[i]
		local color1 = "008051"
		local color2 = "00bf79"
		local color3 = "00ffa1"
		if type(replacements) == "string" then
			local f1, f2 = replacements:find("00ffa1=")
			if f1 and f2 then
				local f3 = replacements:find(";", f2)
				color3 = replacements:sub(f2+1,(f3 or 0)-1)
			end
		else
			for k, v in pairs(replacements) do
				local toReplace = k:lower()
				if toReplace == "00ffa1" then
					color3 = v
					break
				end
			end
		end
		local h, s, v = rgb2hsv(tonumber(color3:sub(1, 2),16) / 255, tonumber(color3:sub(3, 4),16) / 255, tonumber(color3:sub(5, 6),16) / 255)
		color2 = ("%02x%02x%02x"):format(hsv2rgb(h,s,v * 0.75))
		color1 = ("%02x%02x%02x"):format(hsv2rgb(h,s,v * 0.5))

		if color3:len() > 6 then
			local a = color3:sub(7, 8)
			color1 = color1..a
			color2 = color2..a
		end
		if type(replacements) == "string" then
			config.hairColor[i] = replacements .. ("?replace;008051=%s;00bf79=%s;"):format(color1, color2)
		else
			config.hairColor[i]["008051"] = color1
			config.hairColor[i]["00bf79"] = color2
		end
	end
	return config
end

function hsv2rgb(h, s, v)
	local C = v * s
	local m = v - C
	local r, g, b = m, m, m
	if h == h then
		local h_ = (h % 1.0) * 6
		local X = C * (1 - math.abs(h_ % 2 - 1))
		C, X = C + m, X + m
		if h_ < 1 then
			r, g, b = C, X, m
		elseif h_ < 2 then
			r, g, b = X, C, m
		elseif h_ < 3 then
			r, g, b = m, C, X
		elseif h_ < 4 then
			r, g, b = m, X, C
		elseif h_ < 5 then
			r, g, b = X, m, C
		else
			r, g, b = C, m, X
		end
	end
	return math.floor(r * 255), math.floor(g * 255), math.floor(b *255)
end
function rgb2hsv( r, g, b )
	local M, m = math.max( r, g, b ), math.min( r, g, b )
	local C = M - m
	local K = 1.0/(6.0 * C)
	local h = 0.0
	if C ~= 0.0 then
		if M == r then     h = ((g - b) * K) % 1.0
		elseif M == g then h = (b - r) * K + 1.0/3.0
		else               h = (r - g) * K + 2.0/3.0
		end
	end
	return h, M == 0.0 and 0.0 or C / M, M
end
