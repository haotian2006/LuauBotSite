do
	-- simple code written by claude for testing
	local ImageCombineType = {
		BlendSourceOver = 1,
		Overwrite = 2,
		Add = 3,
		Multiply = 4,
		AlphaBlend = 5,
	}

	local ResamplerMode = {
		Default = 0, -- Bilinear filtering
		Pixelated = 1, -- Nearest neighbor
	}

	-- Convert enum to integer (handles both enum objects and direct integers)
	local function enumToInt(value)
		if type(value) == "number" then
			return value
		elseif type(value) == "table" and value.Value then
			return value.Value
		elseif type(value) == "userdata" then
			return value.Value
		end
		return 2 -- Default to Overwrite
	end

	-- Local helper functions (inlined by Luau compiler for optimization)
	local function createImageBuffer(width, height)
		local size = width * height * 4
		return buffer.create(size)
	end

	local function getPixelIndex(x, y, width)
		return ((y * width) + x) * 4
	end

	local function min(a, b)
		return a < b and a or b
	end

	local function max(a, b)
		return a > b and a or b
	end

	local function isInBounds(x, y, width, height)
		return x >= 0 and x < width and y >= 0 and y < height
	end

	-- Bitpack RGBA into a single u32 (R | G << 8 | B << 16 | A << 24)
	local function packRGBA(color, transparency)
		local r = math.floor(color.R * 255)
		local g = math.floor(color.G * 255)
		local b = math.floor(color.B * 255)
		local a = math.floor((1 - transparency) * 255)

		return r + (g * 256) + (b * 65536) + (a * 16777216)
	end

	-- Unpack u32 to RGBA components
	local function unpackRGBA(packed)
		local r = packed % 256
		local g = math.floor(packed / 256) % 256
		local b = math.floor(packed / 65536) % 256
		local a = math.floor(packed / 16777216) % 256
		return r, g, b, a
	end

	-- Blend two colors based on combine type
	local function blendPixels(srcPacked, dstPacked, combineType)
		local sr, sg, sb, sa = unpackRGBA(srcPacked)
		local dr, dg, db, da = unpackRGBA(dstPacked)

		if combineType == 2 then -- Overwrite
			return srcPacked
		elseif combineType == 3 then -- Add
			local r = min(255, sr + dr)
			local g = min(255, sg + dg)
			local b = min(255, sb + db)
			local a = min(255, sa + da)
			return r + (g * 256) + (b * 65536) + (a * 16777216)
		elseif combineType == 4 then -- Multiply
			local r = math.floor((sr / 255) * (dr / 255) * 255)
			local g = math.floor((sg / 255) * (dg / 255) * 255)
			local b = math.floor((sb / 255) * (db / 255) * 255)
			local a = math.floor((sa / 255) * (da / 255) * 255)
			return r + (g * 256) + (b * 65536) + (a * 16777216)
		elseif combineType == 5 then -- AlphaBlend
			local srcAlpha = sa / 255
			local r = math.floor(sr * srcAlpha + dr * (1 - srcAlpha))
			local g = math.floor(sg * srcAlpha + dg * (1 - srcAlpha))
			local b = math.floor(sb * srcAlpha + db * (1 - srcAlpha))
			return r + (g * 256) + (b * 65536) + (sa * 16777216)
		else -- BlendSourceOver (1) or default
			local srcAlpha = sa / 255
			local dstAlpha = da / 255
			local outAlpha = srcAlpha + dstAlpha * (1 - srcAlpha)

			if outAlpha == 0 then
				return 0
			end

			local r = math.floor((sr * srcAlpha + dr * dstAlpha * (1 - srcAlpha)) / outAlpha)
			local g = math.floor((sg * srcAlpha + dg * dstAlpha * (1 - srcAlpha)) / outAlpha)
			local b = math.floor((sb * srcAlpha + db * dstAlpha * (1 - srcAlpha)) / outAlpha)
			local a = math.floor(outAlpha * 255)
			return r + (g * 256) + (b * 65536) + (a * 16777216)
		end
	end

	-- Custom EditableImage class
	Image = {}
	Image.__index = Image

	function Image.new(size: Vector2)
		local self = setmetatable({}, Image)

		-- Store size with clamping
		local width = max(1, min(math.floor(size.X), 1024))
		local height = max(1, min(math.floor(size.Y), 1024))
		self.Size = Vector2.new(width, height)

		-- Create internal buffer to hold image data
		self.imageBuffer = createImageBuffer(width, height)

		return self
	end

	-- Write a pixel to the buffer
	function Image:SetPixel(x: number, y: number, color: Color3, transparency: number, combineType: any?)
		local imgBuffer = self.imageBuffer
		local width, height = self.Size.X, self.Size.Y

		if not isInBounds(x, y, width, height) then
			return
		end

		local idx = getPixelIndex(x, y, width)
		local packed = packRGBA(color, transparency)

		if combineType then
			local mode = enumToInt(combineType)
			if mode ~= 2 then
				local existing = buffer.readu32(imgBuffer, idx)
				packed = blendPixels(packed, existing, mode)
			end
		end

		buffer.writeu32(imgBuffer, idx, packed)
	end

	-- Read a pixel from the buffer
	function Image:GetPixel(x: number, y: number)
		local imgBuffer = self.imageBuffer
		local width, height = self.Size.X, self.Size.Y

		if not isInBounds(x, y, width, height) then
			return Color3.new(0, 0, 0), 1
		end

		local idx = getPixelIndex(x, y, width)

		local r = buffer.readu8(imgBuffer, idx) / 255
		local g = buffer.readu8(imgBuffer, idx + 1) / 255
		local b = buffer.readu8(imgBuffer, idx + 2) / 255
		local a = buffer.readu8(imgBuffer, idx + 3) / 255

		return Color3.new(r, g, b), 1 - a
	end

	-- Fill the entire image with a color
	function Image:Fill(color: Color3, transparency: number)
		local imgBuffer = self.imageBuffer
		local width, height = self.Size.X, self.Size.Y
		local packed = packRGBA(color, transparency)

		for y = 0, height - 1 do
			for x = 0, width - 1 do
				local idx = getPixelIndex(x, y, width)
				buffer.writeu32(imgBuffer, idx, packed)
			end
		end
	end

	-- Draw a rectangle
	function Image:DrawRectangle(
		position: Vector2,
		size: Vector2,
		color: Color3,
		transparency: number,
		combineType: any?
	)
		local imgBuffer = self.imageBuffer
		local width = self.Size.X
		local packed = packRGBA(color, transparency)

		local startX = math.floor(position.X)
		local startY = math.floor(position.Y)
		local endX = math.floor(position.X + size.X)
		local endY = math.floor(position.Y + size.Y)

		startX = max(0, min(startX, self.Size.X - 1))
		startY = max(0, min(startY, self.Size.Y - 1))
		endX = max(0, min(endX, self.Size.X))
		endY = max(0, min(endY, self.Size.Y))

		local mode = combineType and enumToInt(combineType) or 2
		local needsBlend = mode ~= 2

		for y = startY, endY - 1 do
			for x = startX, endX - 1 do
				local idx = getPixelIndex(x, y, width)
				if needsBlend then
					local existing = buffer.readu32(imgBuffer, idx)
					buffer.writeu32(imgBuffer, idx, blendPixels(packed, existing, mode))
				else
					buffer.writeu32(imgBuffer, idx, packed)
				end
			end
		end
	end

	-- Draw an anti-aliased line
	function Image:DrawLine(p1: Vector2, p2: Vector2, color: Color3, transparency: number, combineType: any?)
		combineType = enumToInt(combineType or ImageCombineType.AlphaBlend)

		local x0, y0 = p1.X, p1.Y
		local x1, y1 = p2.X, p2.Y

		-- Xiaolin Wu's line algorithm for anti-aliasing
		local function ipart(x)
			return math.floor(x)
		end

		local function fpart(x)
			return x - math.floor(x)
		end

		local function rfpart(x)
			return 1 - fpart(x)
		end

		local steep = math.abs(y1 - y0) > math.abs(x1 - x0)

		if steep then
			x0, y0 = y0, x0
			x1, y1 = y1, x1
		end

		if x0 > x1 then
			x0, x1 = x1, x0
			y0, y1 = y1, y0
		end

		local dx = x1 - x0
		local dy = y1 - y0
		local gradient = dx == 0 and 1 or dy / dx

		-- Handle first endpoint
		local xend = math.floor(x0 + 0.5)
		local yend = y0 + gradient * (xend - x0)
		local xgap = rfpart(x0 + 0.5)
		local xpxl1 = xend
		local ypxl1 = ipart(yend)

		if steep then
			self:SetPixel(ypxl1, xpxl1, color, transparency + (1 - transparency) * fpart(yend) * xgap, combineType)
			self:SetPixel(ypxl1 + 1, xpxl1, color, transparency + (1 - transparency) * rfpart(yend) * xgap, combineType)
		else
			self:SetPixel(xpxl1, ypxl1, color, transparency + (1 - transparency) * fpart(yend) * xgap, combineType)
			self:SetPixel(xpxl1, ypxl1 + 1, color, transparency + (1 - transparency) * rfpart(yend) * xgap, combineType)
		end

		local intery = yend + gradient

		-- Handle second endpoint
		xend = math.floor(x1 + 0.5)
		yend = y1 + gradient * (xend - x1)
		xgap = fpart(x1 + 0.5)
		local xpxl2 = xend
		local ypxl2 = ipart(yend)

		if steep then
			self:SetPixel(ypxl2, xpxl2, color, transparency + (1 - transparency) * fpart(yend) * xgap, combineType)
			self:SetPixel(ypxl2 + 1, xpxl2, color, transparency + (1 - transparency) * rfpart(yend) * xgap, combineType)
		else
			self:SetPixel(xpxl2, ypxl2, color, transparency + (1 - transparency) * fpart(yend) * xgap, combineType)
			self:SetPixel(xpxl2, ypxl2 + 1, color, transparency + (1 - transparency) * rfpart(yend) * xgap, combineType)
		end

		-- Main loop
		for x = xpxl1 + 1, xpxl2 - 1 do
			if steep then
				self:SetPixel(ipart(intery), x, color, transparency + (1 - transparency) * rfpart(intery), combineType)
				self:SetPixel(
					ipart(intery) + 1,
					x,
					color,
					transparency + (1 - transparency) * fpart(intery),
					combineType
				)
			else
				self:SetPixel(x, ipart(intery), color, transparency + (1 - transparency) * rfpart(intery), combineType)
				self:SetPixel(
					x,
					ipart(intery) + 1,
					color,
					transparency + (1 - transparency) * fpart(intery),
					combineType
				)
			end
			intery = intery + gradient
		end
	end

	-- Draw a circle
	function Image:DrawCircle(center: Vector2, radius: number, color: Color3, transparency: number, combineType: any?)
		local imgBuffer = self.imageBuffer
		local width, height = self.Size.X, self.Size.Y
		local packed = packRGBA(color, transparency)

		local cx = math.floor(center.X)
		local cy = math.floor(center.Y)
		local r = radius
		local rSquared = r * r

		-- Bounding box for circle
		local minX = max(0, math.floor(cx - r))
		local maxX = min(width - 1, math.floor(cx + r))
		local minY = max(0, math.floor(cy - r))
		local maxY = min(height - 1, math.floor(cy + r))

		local mode = combineType and enumToInt(combineType) or 2
		local needsBlend = mode ~= 2

		for y = minY, maxY do
			for x = minX, maxX do
				local dx = x - cx
				local dy = y - cy
				local distSquared = dx * dx + dy * dy

				if distSquared <= rSquared then
					local idx = getPixelIndex(x, y, width)
					if needsBlend then
						local existing = buffer.readu32(imgBuffer, idx)
						buffer.writeu32(imgBuffer, idx, blendPixels(packed, existing, mode))
					else
						buffer.writeu32(imgBuffer, idx, packed)
					end
				end
			end
		end
	end

	-- Get raw buffer access
	function Image:GetBuffer()
		return self.imageBuffer
	end

	-- Clone the buffer
	function Image:Clone()
		local clone = Image.new(self.Size)
		local imgBuffer = self.imageBuffer
		local cloneBuffer = clone.imageBuffer
		local size = self.Size.X * self.Size.Y * 4

		buffer.copy(cloneBuffer, 0, imgBuffer, 0, size)

		return clone
	end

	-- Read a rectangular region of pixels into a buffer
	function Image:ReadPixelsBuffer(position: Vector2, size: Vector2)
		local startX = math.floor(position.X)
		local startY = math.floor(position.Y)
		local regionWidth = math.floor(size.X)
		local regionHeight = math.floor(size.Y)

		-- Clamp to image bounds
		startX = max(0, min(startX, self.Size.X - 1))
		startY = max(0, min(startY, self.Size.Y - 1))
		regionWidth = max(0, min(regionWidth, self.Size.X - startX))
		regionHeight = max(0, min(regionHeight, self.Size.Y - startY))

		-- Create output buffer
		local outputBuffer = buffer.create(regionWidth * regionHeight * 4)
		local imgBuffer = self.imageBuffer
		local imgWidth = self.Size.X

		-- Copy pixels row by row
		for y = 0, regionHeight - 1 do
			for x = 0, regionWidth - 1 do
				local srcIdx = getPixelIndex(startX + x, startY + y, imgWidth)
				local dstIdx = getPixelIndex(x, y, regionWidth)

				-- Copy RGBA bytes
				buffer.writeu8(outputBuffer, dstIdx, buffer.readu8(imgBuffer, srcIdx))
				buffer.writeu8(outputBuffer, dstIdx + 1, buffer.readu8(imgBuffer, srcIdx + 1))
				buffer.writeu8(outputBuffer, dstIdx + 2, buffer.readu8(imgBuffer, srcIdx + 2))
				buffer.writeu8(outputBuffer, dstIdx + 3, buffer.readu8(imgBuffer, srcIdx + 3))
			end
		end

		return outputBuffer
	end

	-- Write a rectangular region of pixels from a buffer
	function Image:WritePixelsBuffer(position: Vector2, size: Vector2, pixelBuffer: any)
		local startX = math.floor(position.X)
		local startY = math.floor(position.Y)
		local regionWidth = math.floor(size.X)
		local regionHeight = math.floor(size.Y)

		-- Clamp to image bounds
		startX = max(0, min(startX, self.Size.X - 1))
		startY = max(0, min(startY, self.Size.Y - 1))
		regionWidth = max(0, min(regionWidth, self.Size.X - startX))
		regionHeight = max(0, min(regionHeight, self.Size.Y - startY))

		local imgBuffer = self.imageBuffer
		local imgWidth = self.Size.X

		-- Copy pixels row by row from input buffer
		for y = 0, regionHeight - 1 do
			for x = 0, regionWidth - 1 do
				local srcIdx = getPixelIndex(x, y, regionWidth)
				local dstIdx = getPixelIndex(startX + x, startY + y, imgWidth)

				-- Copy RGBA bytes
				buffer.writeu8(imgBuffer, dstIdx, buffer.readu8(pixelBuffer, srcIdx))
				buffer.writeu8(imgBuffer, dstIdx + 1, buffer.readu8(pixelBuffer, srcIdx + 1))
				buffer.writeu8(imgBuffer, dstIdx + 2, buffer.readu8(pixelBuffer, srcIdx + 2))
				buffer.writeu8(imgBuffer, dstIdx + 3, buffer.readu8(pixelBuffer, srcIdx + 3))
			end
		end
	end

	-- Simple 5x3 bitmap font (uppercase letters, numbers, and basic symbols)
	local FONT_CHARS = {
		["A"] = { 0x7, 0x5, 0x7, 0x5, 0x5 },
		["B"] = { 0x6, 0x5, 0x6, 0x5, 0x6 },
		["C"] = { 0x7, 0x4, 0x4, 0x4, 0x7 },
		["D"] = { 0x6, 0x5, 0x5, 0x5, 0x6 },
		["E"] = { 0x7, 0x4, 0x6, 0x4, 0x7 },
		["F"] = { 0x7, 0x4, 0x6, 0x4, 0x4 },
		["G"] = { 0x7, 0x4, 0x5, 0x5, 0x7 },
		["H"] = { 0x5, 0x5, 0x7, 0x5, 0x5 },
		["I"] = { 0x7, 0x2, 0x2, 0x2, 0x7 },
		["J"] = { 0x7, 0x1, 0x1, 0x5, 0x7 },
		["K"] = { 0x5, 0x5, 0x6, 0x5, 0x5 },
		["L"] = { 0x4, 0x4, 0x4, 0x4, 0x7 },
		["M"] = { 0x5, 0x7, 0x7, 0x5, 0x5 },
		["N"] = { 0x5, 0x7, 0x7, 0x7, 0x5 },
		["O"] = { 0x7, 0x5, 0x5, 0x5, 0x7 },
		["P"] = { 0x7, 0x5, 0x7, 0x4, 0x4 },
		["Q"] = { 0x7, 0x5, 0x5, 0x7, 0x1 },
		["R"] = { 0x7, 0x5, 0x6, 0x5, 0x5 },
		["S"] = { 0x7, 0x4, 0x7, 0x1, 0x7 },
		["T"] = { 0x7, 0x2, 0x2, 0x2, 0x2 },
		["U"] = { 0x5, 0x5, 0x5, 0x5, 0x7 },
		["V"] = { 0x5, 0x5, 0x5, 0x5, 0x2 },
		["W"] = { 0x5, 0x5, 0x7, 0x7, 0x5 },
		["X"] = { 0x5, 0x5, 0x2, 0x5, 0x5 },
		["Y"] = { 0x5, 0x5, 0x2, 0x2, 0x2 },
		["Z"] = { 0x7, 0x1, 0x2, 0x4, 0x7 },
		["0"] = { 0x7, 0x5, 0x5, 0x5, 0x7 },
		["1"] = { 0x2, 0x6, 0x2, 0x2, 0x7 },
		["2"] = { 0x7, 0x1, 0x7, 0x4, 0x7 },
		["3"] = { 0x7, 0x1, 0x7, 0x1, 0x7 },
		["4"] = { 0x5, 0x5, 0x7, 0x1, 0x1 },
		["5"] = { 0x7, 0x4, 0x7, 0x1, 0x7 },
		["6"] = { 0x7, 0x4, 0x7, 0x5, 0x7 },
		["7"] = { 0x7, 0x1, 0x1, 0x1, 0x1 },
		["8"] = { 0x7, 0x5, 0x7, 0x5, 0x7 },
		["9"] = { 0x7, 0x5, 0x7, 0x1, 0x7 },
		[" "] = { 0x0, 0x0, 0x0, 0x0, 0x0 },
		["."] = { 0x0, 0x0, 0x0, 0x0, 0x2 },
		[","] = { 0x0, 0x0, 0x0, 0x2, 0x4 },
		["!"] = { 0x2, 0x2, 0x2, 0x0, 0x2 },
		["?"] = { 0x7, 0x1, 0x2, 0x0, 0x2 },
		[":"] = { 0x0, 0x2, 0x0, 0x2, 0x0 },
		["-"] = { 0x0, 0x0, 0x7, 0x0, 0x0 },
		["+"] = { 0x0, 0x2, 0x7, 0x2, 0x0 },
		["="] = { 0x0, 0x7, 0x0, 0x7, 0x0 },
		["*"] = { 0x0, 0x5, 0x2, 0x5, 0x0 },
		["/"] = { 0x1, 0x1, 0x2, 0x4, 0x4 },
		["("] = { 0x2, 0x4, 0x4, 0x4, 0x2 },
		[")"] = { 0x2, 0x1, 0x1, 0x1, 0x2 },
		["<"] = { 0x1, 0x2, 0x4, 0x2, 0x1 },
		[">"] = { 0x4, 0x2, 0x1, 0x2, 0x4 },
	}

	-- Draw text on the image
	-- Supports fractional scales (e.g., 1.5) using bilinear sampling for anti-aliased text.
	function Image:DrawText(text: string, position: Vector2, color: Color3, transparency: number, scale: number?)
		-- Accept numbers (including floats) and clamp to a sane minimum
		scale = tonumber(scale) or 1
		if scale < 0.1 then
			scale = 0.1
		end

		local xStart = math.floor(position.X)
		local yStart = math.floor(position.Y)
		local srcW, srcH = 3, 5 -- glyph dimensions

		for i = 1, #text do
			local char = string.sub(text, i, i):upper()
			local glyph = FONT_CHARS[char]

			if glyph then
				-- Fast path: integer scale (exact replication)
				if math.floor(scale) == scale then
					local intScale = math.floor(scale)

					for row = 1, srcH do
						local bits = glyph[row]
						for col = 0, srcW - 1 do
							if bit32.band(bits, bit32.lshift(1, 2 - col)) ~= 0 then
								for sy = 0, intScale - 1 do
									for sx = 0, intScale - 1 do
										self:SetPixel(xStart + col * intScale + sx, yStart + (row - 1) * intScale + sy, color, transparency)
									end
								end
							end
						end
					end

				else
					-- Fractional scale path: render the 3x5 glyph into a dest grid using bilinear sampling
					-- Use nearest-neighbor with slight edge softening for sharper, more readable text
					local destW = math.max(1, math.floor(srcW * scale + 0.5))
					local destH = math.max(1, math.floor(srcH * scale + 0.5))

					local function sampleBit(sx, sy)
						-- Return 0 or 1 depending on glyph bit (safe for out-of-bounds)
						if sx < 0 or sx >= srcW or sy < 0 or sy >= srcH then
							return 0
						end
						local bits = glyph[sy + 1]
						return bit32.band(bits, bit32.lshift(1, 2 - sx)) ~= 0 and 1 or 0
					end

					for dy = 0, destH - 1 do
						for dx = 0, destW - 1 do
							-- Map dest pixel center to source space
							local sx = (dx + 0.5) / scale
							local sy = (dy + 0.5) / scale

							local x0 = math.floor(sx)
							local y0 = math.floor(sy)
							local fx = sx - x0
							local fy = sy - y0

							-- Bilinear sample at pixel center
							local p00 = sampleBit(x0, y0)
							local p10 = sampleBit(x0 + 1, y0)
							local p01 = sampleBit(x0, y0 + 1)
							local p11 = sampleBit(x0 + 1, y0 + 1)

							local s = p00 * (1 - fx) * (1 - fy) + p10 * fx * (1 - fy) + p01 * (1 - fx) * fy + p11 * fx * fy

							-- Apply sharpening threshold to reduce boldness
							-- Values below 0.3 are discarded, values above 0.7 are fully opaque
							if s > 0.3 then
								local sharpened = math.min(1, (s - 0.3) / 0.4)
								local newTransparency = transparency + (1 - sharpened) * (1 - transparency)
								self:SetPixel(xStart + dx, yStart + dy, color, newTransparency)
							end
						end
					end
				end
			end

			-- Advance to next character (3 px glyph + 1 px spacing) scaled
			xStart = xStart + math.max(1, math.floor(4 * scale + 0.5))
		end
	end

	-- Draw another image onto this image with transformations
	function Image:DrawImageTransformed(
		position: Vector2,
		scale: Vector2,
		rotation: number,
		sourceImage: any,
		options: any?
	)
		options = options or {}
		local combineType = options.CombineType or options.combineType or 5 -- Default to AlphaBlend
		local resamplerMode = enumToInt(options.ResamplerMode or options.resamplerMode or ResamplerMode.Default)
		local pivotPoint = options.PivotPoint
			or options.pivotPoint
			or Vector2.new(sourceImage.Size.X / 2, sourceImage.Size.Y / 2)

		-- Get source image dimensions
		local srcWidth = sourceImage.Size.X
		local srcHeight = sourceImage.Size.Y
		local srcBuffer = sourceImage.imageBuffer

		-- Convert rotation from degrees to radians
		local rotationRad = math.rad(rotation)
		local cosTheta = math.cos(rotationRad)
		local sinTheta = math.sin(rotationRad)

		-- Use pivot point from options
		local centerX = pivotPoint.X
		local centerY = pivotPoint.Y

		-- Calculate transformed bounds to determine which pixels to iterate
		local corners = {
			{ 0, 0 },
			{ srcWidth, 0 },
			{ 0, srcHeight },
			{ srcWidth, srcHeight },
		}

		local minX, maxX = math.huge, -math.huge
		local minY, maxY = math.huge, -math.huge

		for _, corner in ipairs(corners) do
			local x, y = corner[1], corner[2]
			-- Translate to pivot point
			x = x - centerX
			y = y - centerY
			-- Apply scale
			x = x * scale.X
			y = y * scale.Y
			-- Apply rotation
			local rotX = x * cosTheta - y * sinTheta
			local rotY = x * sinTheta + y * cosTheta
			-- Translate to position
			rotX = rotX + position.X
			rotY = rotY + position.Y

			minX = min(minX, rotX)
			maxX = max(maxX, rotX)
			minY = min(minY, rotY)
			maxY = max(maxY, rotY)
		end

		-- Clamp to destination bounds
		minX = max(0, math.floor(minX))
		minY = max(0, math.floor(minY))
		maxX = min(self.Size.X - 1, math.ceil(maxX))
		maxY = min(self.Size.Y - 1, math.ceil(maxY))

		-- Determine if we should use bilinear sampling
		local useBilinear = resamplerMode == ResamplerMode.Default

		-- Iterate over destination pixels
		for dy = minY, maxY do
			for dx = minX, maxX do
				-- Transform destination coordinates to source space
				-- Translate to rotation origin
				local px = dx - position.X
				local py = dy - position.Y

				-- Apply inverse rotation
				local rx = px * cosTheta + py * sinTheta
				local ry = -px * sinTheta + py * cosTheta

				-- Apply inverse scale
				rx = rx / scale.X
				ry = ry / scale.Y

				-- Translate back from pivot point
				rx = rx + centerX
				ry = ry + centerY

				if useBilinear then
					-- Bilinear interpolation
					local x0 = math.floor(rx)
					local y0 = math.floor(ry)
					local x1 = x0 + 1
					local y1 = y0 + 1

					local fx = rx - x0
					local fy = ry - y0

					-- Check bounds for all 4 sample points
					local inBounds00 = x0 >= 0 and x0 < srcWidth and y0 >= 0 and y0 < srcHeight
					local inBounds10 = x1 >= 0 and x1 < srcWidth and y0 >= 0 and y0 < srcHeight
					local inBounds01 = x0 >= 0 and x0 < srcWidth and y1 >= 0 and y1 < srcHeight
					local inBounds11 = x1 >= 0 and x1 < srcWidth and y1 >= 0 and y1 < srcHeight

					if inBounds00 or inBounds10 or inBounds01 or inBounds11 then
						-- Sample the 4 pixels
						local function samplePixel(sx, sy)
							if sx >= 0 and sx < srcWidth and sy >= 0 and sy < srcHeight then
								local srcIdx = getPixelIndex(sx, sy, srcWidth)
								return {
									buffer.readu8(srcBuffer, srcIdx),
									buffer.readu8(srcBuffer, srcIdx + 1),
									buffer.readu8(srcBuffer, srcIdx + 2),
									buffer.readu8(srcBuffer, srcIdx + 3),
								}
							end
							return { 0, 0, 0, 0 }
						end

						local p00 = samplePixel(x0, y0)
						local p10 = samplePixel(x1, y0)
						local p01 = samplePixel(x0, y1)
						local p11 = samplePixel(x1, y1)

						-- Bilinear interpolation
						local r = (
							p00[1] * (1 - fx) * (1 - fy)
							+ p10[1] * fx * (1 - fy)
							+ p01[1] * (1 - fx) * fy
							+ p11[1] * fx * fy
						)
						local g = (
							p00[2] * (1 - fx) * (1 - fy)
							+ p10[2] * fx * (1 - fy)
							+ p01[2] * (1 - fx) * fy
							+ p11[2] * fx * fy
						)
						local b = (
							p00[3] * (1 - fx) * (1 - fy)
							+ p10[3] * fx * (1 - fy)
							+ p01[3] * (1 - fx) * fy
							+ p11[3] * fx * fy
						)
						local a = (
							p00[4] * (1 - fx) * (1 - fy)
							+ p10[4] * fx * (1 - fy)
							+ p01[4] * (1 - fx) * fy
							+ p11[4] * fx * fy
						)

						local color = Color3.new(r / 255, g / 255, b / 255)
						local transparency = 1 - a / 255
						self:SetPixel(dx, dy, color, transparency, combineType)
					end
				else
					-- Nearest neighbor (pixelated)
					local sx = math.floor(rx + 0.5)
					local sy = math.floor(ry + 0.5)

					if sx >= 0 and sx < srcWidth and sy >= 0 and sy < srcHeight then
						-- Read source pixel
						local srcIdx = getPixelIndex(sx, sy, srcWidth)
						local r = buffer.readu8(srcBuffer, srcIdx)
						local g = buffer.readu8(srcBuffer, srcIdx + 1)
						local b = buffer.readu8(srcBuffer, srcIdx + 2)
						local a = buffer.readu8(srcBuffer, srcIdx + 3)

						local color = Color3.new(r / 255, g / 255, b / 255)
						local transparency = 1 - a / 255
						self:SetPixel(dx, dy, color, transparency, combineType)
					end
				end
			end
		end
	end

	-- Export types
	Image.ImageCombineType = ImageCombineType
end

PNGEncoder = nil
do
	-- CRC32 lookup table
	local crc32_table = {}
	for i = 0, 255 do
		local c = i
		for j = 1, 8 do
			if c % 2 == 1 then
				c = bit32.bxor(bit32.rshift(c, 1), 0xEDB88320)
			else
				c = bit32.rshift(c, 1)
			end
		end
		crc32_table[i] = c
	end

	-- Calculate CRC32
	local function crc32(data)
		local c = 0xFFFFFFFF
		for i = 1, #data do
			local byte = string.byte(data, i)
			c = bit32.bxor(bit32.rshift(c, 8), crc32_table[bit32.band(bit32.bxor(c, byte), 0xFF)])
		end
		return bit32.bxor(c, 0xFFFFFFFF)
	end

	-- Pack 32-bit big-endian integer
	local function pack32be(value)
		return string.char(
			bit32.band(bit32.rshift(value, 24), 0xFF),
			bit32.band(bit32.rshift(value, 16), 0xFF),
			bit32.band(bit32.rshift(value, 8), 0xFF),
			bit32.band(value, 0xFF)
		)
	end

	-- Create PNG chunk
	local function createChunk(chunkType, data)
		local length = pack32be(#data)
		local typeAndData = chunkType .. data
		local crc = pack32be(crc32(typeAndData))
		return length .. typeAndData .. crc
	end

	-- Adler-32 checksum
	local function adler32(data)
		local s1 = 1
		local s2 = 0

		for i = 1, #data do
			s1 = (s1 + string.byte(data, i)) % 65521
			s2 = (s2 + s1) % 65521
		end

		return s2 * 65536 + s1
	end

	-- Simple DEFLATE compression (uncompressed blocks)
	local function deflate(data)
		local result = string.char(0x78, 0x01) -- zlib header (deflate, default compression)
		local pos = 1
		local dataLen = #data

		while pos <= dataLen do
			local blockSize = math.min(65535, dataLen - pos + 1)
			local isLastBlock = (pos + blockSize - 1 >= dataLen) and 1 or 0

			-- Block header: BFINAL + BTYPE (00 = uncompressed)
			result = result .. string.char(isLastBlock)

			-- LEN and NLEN (little-endian)
			result = result
				.. string.char(
					bit32.band(blockSize, 0xFF),
					bit32.band(bit32.rshift(blockSize, 8), 0xFF),
					bit32.band(bit32.bxor(blockSize, 0xFFFF), 0xFF),
					bit32.band(bit32.rshift(bit32.bxor(blockSize, 0xFFFF), 8), 0xFF)
				)

			-- Block data
			result = result .. string.sub(data, pos, pos + blockSize - 1)
			pos = pos + blockSize
		end

		-- Adler-32 checksum
		local checksum = adler32(data)
		result = result .. pack32be(checksum)

		return result
	end

	PNGEncoder = function(image, shouldLog)
		if shouldLog == nil then
			shouldLog = true
		end
		local println = println
		if not shouldLog then
			println = function() end
		end

		local line = println("PNG: Starting encoding...")
		local width = image.Size.X
		local height = image.Size.Y
		local imgBuffer = image.imageBuffer

		-- PNG signature
		local png = string.char(0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A)

		-- IHDR chunk
		local ihdr = pack32be(width) .. pack32be(height)
		ihdr = ihdr
			.. string.char(
				8, -- bit depth
				6, -- color type (RGBA)
				0, -- compression method
				0, -- filter method
				0 -- interlace method
			)
		png = png .. createChunk("IHDR", ihdr)

		println("PNG: Reading pixels...", line)
		task.wait()

		-- IDAT chunk (image data)
		local imageData = {}

		for y = 0, height - 1 do
			-- Filter type 0 (none) for each scanline
			table.insert(imageData, string.char(0))

			for x = 0, width - 1 do
				local idx = ((y * width) + x) * 4
				local r = buffer.readu8(imgBuffer, idx)
				local g = buffer.readu8(imgBuffer, idx + 1)
				local b = buffer.readu8(imgBuffer, idx + 2)
				local a = buffer.readu8(imgBuffer, idx + 3)

				table.insert(imageData, string.char(r, g, b, a))
			end

			-- Progress update every 10 rows
			if y % 10 == 0 then
				local progress = math.floor((y / (height - 1)) * 100)
				println(string.format("PNG: Reading pixels... %d%%", progress), line)
				task.wait()
			end
		end

		println("PNG: Compressing...", line)
		task.wait()

		local rawData = table.concat(imageData)
		local compressed = deflate(rawData)
		png = png .. createChunk("IDAT", compressed)

		-- IEND chunk
		png = png .. createChunk("IEND", "")

		println("PNG: Encoding complete!", line)
		task.wait()

		return png
	end
end

-- =========================
-- GIF Encoder (Palette + Indexed Pixels)
-- =========================
GIFEncoder = nil
do
	-- Write 16-bit little endian
	local function u16le(n)
		return string.char(bit32.band(n, 0xFF), bit32.band(bit32.rshift(n, 8), 0xFF))
	end

	-- BitWriter for LZW (LSB-first) - simple and reliable
	local function BitWriter()
		return {
			buffer = 0,
			bufferBits = 0,
			output = {},

			writeBits = function(self, value, bitCount)
				-- Add bits to buffer
				self.buffer = self.buffer + value * (2 ^ self.bufferBits)
				self.bufferBits = self.bufferBits + bitCount

				-- Output complete bytes
				while self.bufferBits >= 8 do
					local byte = self.buffer % 256
					table.insert(self.output, string.char(byte))
					self.buffer = math.floor(self.buffer / 256)
					self.bufferBits = self.bufferBits - 8
				end
			end,

			flush = function(self)
				if self.bufferBits > 0 then
					table.insert(self.output, string.char(self.buffer % 256))
				end
			end,

			getData = function(self)
				return table.concat(self.output)
			end,
		}
	end

	-- LZW Compression for GIF - following GIF89a spec exactly
	local function lzwCompress(indices, minCodeSize)
		local CLEAR = 2 ^ minCodeSize
		local EOI = CLEAR + 1

		-- Initialize dictionary
		local dict = {}
		local dictSize = EOI + 1
		local codeSize = minCodeSize + 1

		local writer = BitWriter()

		-- Write CLEAR code to start
		writer:writeBits(CLEAR, codeSize)

		-- Start with empty string (per GIF spec)
		local w = ""

		for i = 1, #indices do
			local k = string.char(indices[i])
			local wk = w .. k

			-- Check if wk exists (either in dict or as root code)
			local wkCode = dict[wk]
			if not wkCode and #wk == 1 then
				-- Single character is a root code (0-255)
				wkCode = string.byte(wk)
			end

			if wkCode then
				-- String exists, continue building
				w = wk
			else
				-- String not found, output code for w and add wk to dictionary
				local code = dict[w]
				if not code and #w > 0 then
					-- Single character root code
					code = string.byte(w)
				end

				if code then
					writer:writeBits(code, codeSize)
				end

				-- Add wk to dictionary if there's room
				if dictSize < 4096 then
					dict[wk] = dictSize
					dictSize = dictSize + 1

					-- Increase code size AFTER adding entry (when next code won't fit)
					if dictSize > (2 ^ codeSize) and codeSize < 12 then
						codeSize = codeSize + 1
					end
				end

				-- Reset dictionary when full
				if dictSize >= 4096 then
					writer:writeBits(CLEAR, codeSize)
					dict = {}
					dictSize = EOI + 1
					codeSize = minCodeSize + 1
				end

				w = k
			end
		end

		-- Output code for any remaining string
		if #w > 0 then
			local code = dict[w]
			if not code then
				code = string.byte(w)
			end
			writer:writeBits(code, codeSize)
		end

		-- Write EOI (End Of Information)
		writer:writeBits(EOI, codeSize)

		-- Flush remaining bits
		writer:flush()

		-- Pack into GIF sub-blocks (max 255 bytes per block)
		local data = writer:getData()
		local blocks = {}
		local pos = 1
		while pos <= #data do
			local len = math.min(255, #data - pos + 1)
			table.insert(blocks, string.char(len) .. string.sub(data, pos, pos + len - 1))
			pos = pos + len
		end
		table.insert(blocks, string.char(0)) -- Block terminator

		return table.concat(blocks)
	end

	-- Quantize 24-bit RGB to 256-color palette (simple 3-3-2)
	local function quantize(r, g, b)
		local ri = math.floor(r / 256 * 8)
		local gi = math.floor(g / 256 * 8)
		local bi = math.floor(b / 256 * 4)
		return math.min(ri, 7) * 32 + math.min(gi, 7) * 4 + math.min(bi, 3)
	end

	-- Build 256-color global palette (3-3-2)
	local function buildGlobalPalette()
		local t = {}
		for i = 0, 255 do
			local r = bit32.band(bit32.rshift(i, 5), 7)
			local g = bit32.band(bit32.rshift(i, 2), 7)
			local b = bit32.band(i, 3)
			t[#t + 1] =
				string.char(math.floor(r / 7 * 255 + 0.5), math.floor(g / 7 * 255 + 0.5), math.floor(b / 3 * 255 + 0.5))
		end
		return table.concat(t)
	end

	GIFEncoder = function(frames, durations, options, shouldLog)
		if shouldLog == nil then
			shouldLog = true
		end
		local println = println
		if not shouldLog then
			println = function() end
		end

		local line = println("GIF: Starting encoding...")
		options = options or {}
		local loopCount = options.loop or 0
		assert(#frames > 0)
		assert(#frames == #durations)
		local width = frames[1].Size.X
		local height = frames[1].Size.Y

		local out = {}
		out[#out + 1] = "GIF89a"
		out[#out + 1] = u16le(width) .. u16le(height) .. string.char(0xF7, 0x00, 0x00)

		println("GIF: Building palette...", line)
		task.wait()
		local palette = buildGlobalPalette()
		out[#out + 1] = palette

		-- Netscape Loop
		out[#out + 1] = "\x21\xFF\x0BNETSCAPE2.0\x03\x01" .. u16le(loopCount) .. "\x00"

		println(string.format("GIF: Encoding %d frames...", #frames), line)
		task.wait()

		for i = 1, #frames do
			local img = frames[i]
			local delay = math.floor(durations[i] * 100 + 0.5)

			println(string.format("GIF: Frame %d/%d - Quantizing pixels...", i, #frames), line)
			task.wait()

			-- Graphics Control Extension
			out[#out + 1] = "\x21\xF9\x04" .. string.char(0x00) .. u16le(delay) .. string.char(0x00, 0x00)
			-- Image Descriptor
			out[#out + 1] = "\x2C" .. u16le(0) .. u16le(0) .. u16le(width) .. u16le(height) .. string.char(0x00)

			-- Convert pixels to palette indices
			local indices = {}
			local buf = img.imageBuffer
			for y = 0, height - 1 do
				for x = 0, width - 1 do
					local p = ((y * width) + x) * 4
					local r = buffer.readu8(buf, p)
					local g = buffer.readu8(buf, p + 1)
					local b = buffer.readu8(buf, p + 2)
					indices[#indices + 1] = quantize(r, g, b)
				end
			end

			println(string.format("GIF: Frame %d/%d - LZW compressing...", i, #frames), line)
			task.wait()

			-- Minimum code size for LZW
			out[#out + 1] = string.char(8)
			out[#out + 1] = lzwCompress(indices, 8)
		end

		println("GIF: Finalizing...", line)
		task.wait()

		out[#out + 1] = string.char(0x3B) -- GIF Trailer

		println("GIF: Encoding complete!", line)
		task.wait()

		return table.concat(out)
	end
end

local frames = {}
local durations = {}

for i = 1, 15 do
	local img = Image.new(Vector2.new(400, 300))

	-- Gradient background (changes color each frame)
	local bgHue = (i - 1) / 15
	img:Fill(Color3.new(0.1 + bgHue * 0.2, 0.2 + bgHue * 0.3, 0.5 + bgHue * 0.4), 0)

	-- Title text at top
	img:DrawText("BOUNCING BALL DEMO", Vector2.new(50, 20), Color3.new(1, 1, 1), 0, 2)

	-- Frame counter
	img:DrawText(string.format("FRAME: %d/15", i), Vector2.new(20, 260), Color3.new(1, 1, 1), 0, 1)

	-- Bouncing ball animation
	local t = (i - 1) / 14
	local x = 60 + t * 280
	local y = 150 - math.abs(math.sin(t * math.pi * 3)) * 80

	-- Draw ball with gradient effect
	img:DrawCircle(Vector2.new(x, y), 30, Color3.new(1, 0, 0), 0)
	img:DrawCircle(Vector2.new(x, y), 24, Color3.new(1, 0.5, 0), 0)
	img:DrawCircle(Vector2.new(x, y), 18, Color3.new(1, 1, 0), 0)
	img:DrawCircle(Vector2.new(x - 6, y - 6), 8, Color3.new(1, 1, 0.8), 0)

	-- Floor line
	img:DrawRectangle(Vector2.new(0, 230), Vector2.new(400, 4), Color3.new(0.3, 0.3, 0.3), 0)

	table.insert(frames, img)
	table.insert(durations, 0.08)
end

-- Export to GIF
local gifData = GIFEncoder(frames, durations, {
	loop = 0, -- Infinite loop
})

io.writeFile(gifData, "gif")

-- Simple up-and-down ball GIF example

local frames_ball = {}
local durations_ball = {}
local w, h = 200, 200
local total = 40

for i = 1, total do
	local img = Image.new(Vector2.new(w, h))

	img:Fill(Color3.new(1, 1, 1), 0)

	local t = (i - 1) / (total - 1)
	local midX = w / 2
	local midY = h / 2
	local amp = 60
	local y = midY + math.sin(t * math.pi * 2) * amp

	img:DrawCircle(Vector2.new(midX, y), 20, Color3.new(1, 0, 0.866667), 0)

	frames_ball[#frames_ball + 1] = img
	durations_ball[#durations_ball + 1] = 1 / 30
end

local gifData = Image.toGif(frames_ball, durations_ball, nil, true)
io.writefile(gifData, "ball.gif")
