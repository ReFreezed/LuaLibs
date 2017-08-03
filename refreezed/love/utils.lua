--[[============================================================
--=
--=  Utilities for LÖVE
--=
--=  Dependencies:
--=  - LÖVE 0.10.2 (optional)
--=
--=-------------------------------------------------------------
--=
--=  MIT License
--=
--=  Copyright © 2017 Marcus 'ReFreezed' Thunström
--=
--=  Permission is hereby granted, free of charge, to any person obtaining a copy
--=  of this software and associated documentation files (the "Software"), to deal
--=  in the Software without restriction, including without limitation the rights
--=  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
--=  copies of the Software, and to permit persons to whom the Software is
--=  furnished to do so, subject to the following conditions:
--=
--=  The above copyright notice and this permission notice shall be included in all
--=  copies or substantial portions of the Software.
--=
--=  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
--=  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
--=  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
--=  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
--=  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
--=  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
--=  SOFTWARE.
--=
--==============================================================

	colorComponents
	getTextHeight
	rgbToHsl, hslToRgb, rgbToHsv, hsvToRgb

	LÖVE:
	- fillRectangle
	- mixColor
	- newGradient
	- roundedRectangle

--============================================================]]



local LG = (love and love.graphics)

local floor, pi = math.floor, math.pi

local M = {}







--==============================================================
--==============================================================
--==============================================================
--==============================================================
--==============================================================

local indexOf







-- indexOf( table, value )
function indexOf(t, v)
	for i, item in ipairs(t) do
		if (item == v) then
			return i
		end
	end
	return nil
end







--==============================================================
--==============================================================
--==============================================================
--==============================================================
--==============================================================







-- red, green, blue = colorComponents( color:uint )
-- red, green, blue, alpha = colorComponents( colorWithAlpha:uint [, includeAlpha=false ] )
-- color: 0xRRGGBB
-- colorWithAlpha: 0xAARRGGBB
-- Examples:
--   local r, g, b = colorComponents(0x39FFA0)
--   local r, g, b, a = colorComponents(0x7039FFA0, true)
function M.colorComponents(color, includeAlpha)
	if (includeAlpha) then
		return
			floor(color/65536),   -- 255^2
			floor(color/256)%256, -- 255^1
			color%256,            -- 255^0
			floor(color/16777216) -- 255^3
	else
		return
			floor(color/65536),   -- 255^2
			floor(color/256)%256, -- 255^1
			color%256             -- 255^0
	end
end







-- height = getTextHeight( font, text [, wrapLimit=none ] )
function M.getTextHeight(font, text, wrapLimit)
	local lineCount, _
	if (wrapLimit) then
		_, lineCount = font:getWrap(text, wrapLimit)
		lineCount = #lineCount
	else
		_, lineCount = text:gsub('\n', '')
		lineCount = lineCount+1
	end
	local h = font:getHeight()
	return h+math.floor(h*font:getLineHeight()*(lineCount-1))
end







-- hue, saturation, lightness = rgbToHsl( red, green, blue )
function M.rgbToHsl(r, g, b)
	r, g, b = r/255, g/255, b/255

	local max, min = math.max(r, g, b), math.min(r, g, b)
	local h, s, l

	l = (max+min)/2

	if (max == min) then
		h, s = 0, 0 -- achromatic
	else
		local d = max-min
		local s
		if (l > 0.5) then s = d/(2-max-min); else s = d/(max+min); end
		if (max == r) then
			h = (g-b)/d
			if (g < b) then h = h+6 end
		elseif (max == g) then h = (b-r)/d+2;
		elseif (max == b) then h = (r-g)/d+4;
		end
		h = h/6
	end

	return h, s, l
end



-- red, green, blue = hslToRgb( hue, saturation, lightness )
do

	local function hue2rgb(p, q, t)
		if (t < 0)   then t = t+1; end
		if (t > 1)   then t = t-1; end
		if (t < 1/6) then return p+(q-p)*6*t; end
		if (t < 1/2) then return q; end
		if (t < 2/3) then return p+(q-p)*(2/3-t)*6; end
		return p
	end

	function M.hslToRgb(h, s, l)
		local r, g, b

		if (s == 0) then
			r, g, b = l, l, l -- achromatic
		else

			local q
			if (l < 0.5) then q = l*(1+s); else q = l+s-l*s; end
			local p = 2*l-q

			r = hue2rgb(p, q, h+1/3)
			g = hue2rgb(p, q, h)
			b = hue2rgb(p, q, h-1/3)
		end

		return floor(r*255+0.5), floor(g*255+0.5), floor(b*255+0.5)
	end

end



-- hue, saturation, value = rgbToHsv( red, green, blue )
function M.rgbToHsv(r, g, b)
	r, g, b = r/255, g/255, b/255
	local max, min = math.max(r, g, b), math.min(r, g, b)
	local h, s, v
	v = max

	local d = max-min
	if (max == 0) then s = 0; else s = d/max; end

	if (max == min) then
		h = 0 -- achromatic
	else
		if (max == r) then
			h = (g-b)/d
			if (g < b)    then h = h+6; end
		elseif (max == g) then h = (b-r)/d+2;
		elseif (max == b) then h = (r-g)/d+4;
		end
		h = h/6
	end

	return h, s, v
end



-- red, green, blue = hsvToRgb( hue, saturation, value )
function M.hsvToRgb(h, s, v)
	local r, g, b

	local i = floor(h*6)
	local f = h*6-i
	local p = v*(1-s)
	local q = v*(1-f*s)
	local t = v*(1-(1-f)*s)

	i = i%6

	if     i == 0 then r, g, b = v, t, p
	elseif i == 1 then r, g, b = q, v, p
	elseif i == 2 then r, g, b = p, v, t
	elseif i == 3 then r, g, b = p, q, v
	elseif i == 4 then r, g, b = t, p, v
	elseif i == 5 then r, g, b = v, p, q
	end

	return floor(r*255+0.5), floor(g*255+0.5), floor(b*255+0.5)
end







--= LÖVE
--==============================================================

if (love) then







-- fillRectangle( image, [ quad, ] x, y, w, h [, r, ox, oy, kx, ky ] )
do

	local function fillRectangleQuad(img, quad, x, y, w, h, r, ...)
		local _, _, qw, qh = quad:getViewport()
		return LG.draw(img, quad, x, y, r, w/qw, h/qh, ...)
	end

	function M.fillRectangle(img, x, y, w, h, r, ...)
		if (type(x) == 'userdata') then
			return fillRectangleQuad(img, x, y, w, h, r, ...)
		else
			return LG.draw(img, x, y, r, w/img:getWidth(), h/img:getHeight(), ...)
		end
	end

end







-- mixColor( red, green, blue [, alpha=255 ] )
function M.mixColor(r2, g2, b2, a2)
	local r, g, b, a = LG.getColor()
	LG.setColor(r*r2/255, g*g2/255, b*b2/255, a*(a2 or 255)/255)
end







-- gradientImage = newGradient( colors )
-- Example:
-- local rainbow = newGradient{
--   direction = "horizontal",
--   {255, 0, 0},
--   {255, 255, 0},
--   {0, 255, 0},
--   {0, 255, 255},
--   {0, 0, 255},
--   {255, 0, 0},
-- }
function M.newGradient(colors)
	local dir, vertical = colors.direction
	if (dir == nil or dir == 'horizontal') then
		vertical = false
	elseif (dir == 'vertical') then
		vertical = true
	else
		error('bad direction (expected "horizontal" or "vertical", got "'..tostring(dir)..'")')
	end
	local imageData = love.image.newImageData((vertical and 1 or #colors), (vertical and #colors or 1))
	for i, color in ipairs(colors) do
		local x, y = (vertical and 0 or i-1), (vertical and i-1 or 0)
		imageData:setPixel(x, y, unpack(color))
	end
	return LG.newImage(imageData)
end







-- roundedRectangle( x, y, width, height, radius )
function M.roundedRectangle(x, y, w, h, r)
	LG.rectangle('fill', x, y+r, w, h-r*2)
	LG.rectangle('fill', x+r, y, w-r*2, r)
	LG.rectangle('fill', x+r, y+h-r, w-r*2, r)
	LG.arc('fill', x+r, y+r, r, pi, pi*1.5)
	LG.arc('fill', x+w-r, y+r, r, -pi*0.5, 0)
	LG.arc('fill', x+w-r, y+h-r, r, 0, pi*0.5)
	LG.arc('fill', x+r, y+h-r, r, pi*0.5, pi)
end







end--if love

--==============================================================
--==============================================================
--==============================================================
--==============================================================
--==============================================================

return M
