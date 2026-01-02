

A library to create images similar to the [EditableImage](https://create.roblox.com/docs/reference/engine/classes/EditableImage) class in Roblox.

## Functions

### `new(size:Vector2): Image`
Creates a new Image object with the specified size.

### `toPng(image:Image,outputLogs:boolean?): string`
Encodes the Image object as a raw string encoded as a png. If `outputLogs` is true, logs will be printed during the encoding process.

```lua
local img = Image.new(Vector2.new(400, 300))
img:Fill(Color3.new(1, 1, 1), 0)

img:DrawCircle(Vector2.new(200, 150), 60, Color3.new(1, 0, 0), 0.25)

img:DrawRectangle(Vector2.new(20, 20), Vector2.new(100, 60), Color3.new(0, 0.4, 1), 0)
img:DrawLine(Vector2.new(20, 20), Vector2.new(120, 80), Color3.new(0, 0, 0), 0.5)

img:DrawText("Example Image", Vector2.new(25, 35), Color3.new(1, 1, 1), 0, 1)

local badge = Image.new(Vector2.new(80, 80))
badge:Fill(Color3.new(0, 0, 0), 0)
badge:DrawCircle(Vector2.new(40, 40), 30, Color3.new(1, 0.8, 0.2), 0)
img:DrawImageTransformed(Vector2.new(300, 40), Vector2.new(1, 1), 20, badge, {PivotPoint = Vector2.new(0.5, 0.5)})

local pngData = Image.toPng(img, true) 
io.writefile(pngData, "example.png")
```

### `toGif(frames:{Image},frameDelays:{number},options: {},outputLogs:boolean?): string`
Encodes multiple Image objects as a raw string encoded as a gif. `frameDelays` is an array of numbers representing the delay for each frame in seconds. `options` is a table that can contain the following optional fields:
- `loop`: number of times to loop the gif (0 for infinite)

```lua
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
```

## Properties

### `Size: Vector2`
The size of the image in pixels.

## Methods

### `SetPixel((x: number, y: number, color: Color3, transparency: number, combineType: Enum.ImageCombineType?)`
Sets the pixel at the specified (x, y) coordinates to the given color and transparency. The optional [combineType](https://create.roblox.com/docs/reference/engine/enums/ImageCombineType) parameter determines how the new color is combined with the existing color at that pixel. Default is `Enum.ImageCombineType.Overwrite`.

### `GetPixel(x: number, y: number): (Color3, number)`
Returns the color and transparency of the pixel at the specified (x, y) coordinates.

### `Fill(color: Color3, transparency: number)`
Fills the entire image with the specified color and transparency.

### `DrawRectangle(position: Vector2, size: Vector2, color: Color3, transparency: number,combineType: Enum.ImageCombineType?)`
Draws a rectangle at the specified position with the given size, color, and transparency. The optional [combineType](https://create.roblox.com/docs/reference/engine/enums/ImageCombineType) parameter determines how the new color is combined with the existing colors in the rectangle area. Default is `Enum.ImageCombineType.Overwrite`.

### `DrawLine(startPos: Vector2, endPos: Vector2, color: Color3, transparency: number, combineType: Enum.ImageCombineType?)`
Draws a line from `startPos` to `endPos` with the specified color and transparency. The optional [combineType](https://create.roblox.com/docs/reference/engine/enums/ImageCombineType) parameter determines how the new color is combined with the existing colors along the line. Default is `Enum.ImageCombineType.Overwrite`.

### `DrawCircle(center: Vector2, radius: number, color: Color3, transparency: number, combineType: Enum.ImageCombineType?)`
Draws a circle with the specified center, radius, color, and transparency. The optional [combineType](https://create.roblox.com/docs/reference/engine/enums/ImageCombineType) parameter determines how the new color is combined with the existing colors in the circle area. Default is `Enum.ImageCombineType.Overwrite`.

### `DrawText(text: string, position: Vector2, color: Color3, transparency: number, scale: number?)`
Renders the specified text at the given position with the specified color, transparency, and scale.

- The `scale` parameter adjusts the size of the text. It accepts non-integer values (for example, `1.5`) and will render anti-aliased text using bilinear sampling.
- Note: non-integer scales may result in slightly blurry text/unreadable.
- Invalid characters will be ignored.

Example:

```lua
local img = Image.new(Vector2.new(300, 100))
img:Fill(Color3.new(1, 1, 1), 0)
img:DrawText("Scale 1.0", Vector2.new(10, 10), Color3.new(0, 0, 0), 0, 1)
img:DrawText("Scale 1.5", Vector2.new(10, 30), Color3.new(0, 0, 0), 0, 1.5)
img:DrawText("Scale 2.0", Vector2.new(10, 55), Color3.new(0, 0, 0), 0, 2)
img:DrawText("Scale 2.25", Vector2.new(10, 80), Color3.new(0, 0, 0), 0, 2.25)

local png = Image.toPng(img, true)
io.writefile(png, "png")
```

### `DrawImageTransformed(position: Vector2, scale: Vector2, rotation: number, sourceImage: any, options: {}?)`
Draws another image onto this image at the specified position, with scaling and rotation applied. The `options` table can contain the following optional fields:

- `CombineType`: [Enum.ImageCombineType](https://create.roblox.com/docs/reference/engine/enums/ImageCombineType) - Determines how the source image is combined with the destination image. Default is `Enum.ImageCombineType.AlphaBlend`.
- `ResamplerMode`: [Enum.ResamplerMode](https://create.roblox.com/docs/reference/engine/enums/ResamplerMode) - Specifies the resampling mode to use when scaling the source image. Default is `Enum.ImageResamplerMode.Bilinear`.
- `PivotPoint`: Vector2 - The pivot point for rotation, specified as a fraction of the image size (0 to 1). Default is (0.5, 0.5) which represents the center of the image.

### `ReadPixelsBuffer(position: Vector2, size: Vector2): buffer`
Returns a buffer containing the raw pixel data of the image.

### `WritePixelsBuffer(position: Vector2, size: Vector2, pixelBuffer: buffer)`
Writes raw pixel data from a buffer to the image at the specified position and size.

### `GetBuffer(): buffer`
Returns the entire image's pixel data buffer

### `Clone(): Image`
Creates and returns a copy of the Image object.