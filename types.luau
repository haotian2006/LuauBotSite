--[==[IGNORE START]==]
local TIMEOUT, OUTPUT_LOGS, TIMESTAMP, native, optimize
local bench, println, log, user, colorstring
local etable, io, misc, Image
--Collapse this block to help with readability
do
	-- Global variable types
	type TIMEOUT = number
	type OUTPUT_LOGS = boolean | "LOG"
	type TIMESTAMP = boolean
	type native = boolean
	type optimize = number
	type user = {
		Name: string,
		UserId: number,
	}

	type colorstring = typeof( --[[
			Returns the input string wrapped in color tags for console output.
			
			@param text string - The text to color.
			@param color string - The color to apply (black, red, green, yellow, blue, purple, white, cyan).
			@return string - The colored text string.
		]]function(text: string, color: string): string
		return text
	end)
	-- Benchmark types
	export type BenchFuncs = { [string]: () -> any }
	export type BenchResults = {
		[string]: {
			Mean: number,
			Median: number,
			Min: number,
			Max: number,
			StdDev: number,
		},
	}

	export type BenchFuncsWithParams = {
		ParameterGenerator: () -> any,
		Functions: { [string]: (profile: any, ...any) -> any },
	}

	type bench = typeof( --[[
			Runs benchmarks on the provided functions.
			
			@param funcs {[string]: () -> any} | BenchFuncsWithParams - A dictionary of functions to benchmark or BoatBomber's format.
			@param printMode number? - Determines how results are printed (0 = No output, 1 = table format, 2 = compact format).
			@param iterations number? - The number of iterations to run for each function. Defaults to 1000.
			@param delayEveryXIter number? - Introduces a small delay every X iterations to prevent timeouts. Defaults to 20.
			@return BenchResults - A table containing the results of the benchmarks.
		]]function(
		funcs: BenchFuncs | BenchFuncsWithParams,
		printMode: number?,
		iterations: number?,
		delayEveryXIter: number?
	): BenchResults
		return {}
	end)

	export type println = typeof( --[[
			Prints text to the console and returns the line number it was printed on.
			
			@param message string - The text to print.
			@param line number? - Optional line number to overwrite.
			@return number - The line number the text was printed on.
		]]function(message: string, line: number?): number
		return 1
	end)

	type log = typeof( --[[
			Logs text to the console with a specified color.
			
			@param text string - The text to log.
			@param color string - The color to use (black, red, green, yellow, blue, purple, white, cyan).
			@param newLine boolean? - If true, adds a new line after the text.
		]]function(text: string, color: string, newLine: boolean?) end)

	-- Extended Table Library type
	type etable = {
		-- Memory and Size Functions
		getAllocatedArraySize: (tbl: { any }) -> number,
		getAllocatedHashSize: (tbl: { any }) -> number,
		getTableMemorySize: (tbl: { any }, includeContents: boolean?) -> number,
		getTableSize: (tbl: { any }, isContiguous: boolean?) -> number,

		-- Merging and Combining
		mergeTables: (inPlace: boolean?, depth: number?, ...{ any }) -> { any },
		mergeTablesWith: (
			inPlace: boolean?,
			depth: number?,
			resolver: (key: any, value1: any, value2: any) -> any,
			...{ any }
		) -> { any },
		accumulateTables: (inPlace: boolean?, ...{ any }) -> { any },
		diffTables: (old: { any }, new: { any }) -> { any },
		syncTable: (src: { any }, target: { any }) -> (),

		-- Mapping and Filtering
		mapTable: <K, V, NK, NV>(tbl: { [K]: V }, callback: (key: K, value: V) -> (NK, NV)) -> { [NK]: NV },
		filterTable: <K, V>(
			tbl: { [K]: V },
			predicate: (key: K, value: V) -> boolean,
			preAllocate: boolean?
		) -> { [K]: V },
		reduceTable: <K, V, R>(tbl: { [K]: V }, reducer: (accumulator: R, key: K, value: V) -> R, initial: R) -> R,
		groupTableBy: <K, V>(tbl: { [K]: V }, callback: (key: K, value: V) -> any) -> { [any]: { [K]: V } },

		-- Conversion and Transformation
		tableToPairs: <K, V>(tbl: { [K]: V }) -> { { key: K, value: V } },
		invertTable: <K, V>(tbl: { [K]: V }) -> { [V]: K },
		tableIntersection: <K, V>(tbl1: { [K]: V }, tbl2: { [K]: V }, matchValue: boolean?) -> { [K]: V },
		tableDifference: <K, V>(
			tbl1: { [K]: V },
			tbl2: { [K]: V },
			matchValue: boolean?,
			symmetric: boolean?
		) -> { [K]: V },

		-- Remove Operations
		removeAll: (tbl: { any }, value: any | { any }) -> (),

		-- Array Operations
		extendArraySize: (tbl: { any }, expandSize: number) -> (),
		setArraySize: (tbl: { any }, newSize: number) -> (),
		truncateArray: (array: { any }, newSize: number) -> (),
		concatArrays: (inPlace: boolean?, ...{ any }) -> { any },
		unionArrays: (...{ any }) -> { any },
		flattenArray: (src: { any }, depth: number?) -> { any },
		compactArray: (array: { any }, allocateExactSize: boolean?, isArray: boolean?) -> { any },

		-- Array Fill Operations
		fillWithValue: <T>(
			array: { T },
			value: T,
			startIndex: number?,
			endIndex: number?,
			sourceArray: { T }?
		) -> (),
		fillWithPattern: <T>(array: { T }, pattern: { T }, startIndex: number?, endIndex: number?) -> (),

		-- Array Manipulation
		reverseArray: <T>(array: { T }) -> (),
		rotateArray: <T>(array: { T }, shift: number) -> (),
		sliceArray: <T>(array: { T }, startIndex: number?, endIndex: number?) -> { T },
		shuffleArray: <T>(array: { T }) -> (),
		sampleArray: <T>(array: { T }, sampleSize: number, allowDuplicates: boolean?) -> { T },
		sampleValue: <T>(array: { T }, startIndex: number?, endIndex: number?) -> T,

		-- Array Deduplication and Removal
		removeDuplicate: <T>(array: { T }, by: ((value: T) -> any)?) -> { T },
		swapRemove: <T>(array: { T }, index: number) -> T?,
		getAndRemove: <T>(array: { T }, index: number, swap: boolean?) -> T?,
		findAndRemove: <T>(array: { T }, value: T, swap: boolean?) -> boolean,

		-- Array Utilities
		zipArray: (...{ any }) -> { { any } },
		unzipArray: (zippedArray: { { any } }) -> ...{ any },
		partitionArray: <T>(array: { T }, size: number) -> { { T } },
		partitionArrayBy: <T>(array: { T }, predicate: (value: T) -> boolean) -> ({ T }, { T }),
		binarySearch: <T>(array: { T }, value: T, comparator: ((a: T, b: T) -> number)?) -> number?,

		-- Table Inspection
		getKeys: <K, V>(tbl: { [K]: V }) -> { K },
		getValues: <K, V>(tbl: { [K]: V }) -> { V },
		isContiguousArray: (tbl: { any }) -> boolean,
		isSparseArray: (tbl: { any }) -> boolean,
		isArray: (tbl: { any }) -> boolean,
		isEmpty: (tbl: { any }) -> boolean,
		hasKey: <K>(tbl: { [K]: any }, key: K) -> boolean,
		hasValue: <V>(tbl: { [any]: V }, value: V) -> boolean,

		-- Counting and Finding
		countOccurences: <V>(tbl: { [any]: V }, value: V) -> number,
		countKeysByType: (tbl: { [any]: any }, keyType: string) -> number,
		countValuesByType: (tbl: { [any]: any }, valueType: string) -> number,
		keysOfValue: <K, V>(tbl: { [K]: V }, targetValue: V) -> { K },

		-- Deep Operations
		deepCopy: <T>(tbl: T) -> T,
		deepEqual: (a: any, b: any) -> boolean,
		deepFreeze: (tbl: { any }, layers: number?) -> (),

		-- Predicates
		findMatch: <K, V>(tbl: { [K]: V }, filter: (key: K, value: V) -> boolean) -> K?,
		every: <K, V>(tbl: { [K]: V }, filter: (key: K, value: V) -> boolean) -> boolean,
		some: <K, V>(tbl: { [K]: V }, filter: (key: K, value: V) -> boolean) -> boolean,

		-- Set Operations
		toSet: <T>(tbl: { T }) -> { [T]: true },
	}

	-- IO Library type
	type io = {
		followupnext: typeof( --[[
				Marks the next output as a followup message with ephemeral set to true.
				
				This message will be sent as a followup and the original compiler embed will be updated.
			]]function() end),

		write: typeof( --[[
				Writes output without adding spaces between arguments and without expanding tables.
				
				If TIMESTAMP is false, it will not create a new line.
				
				@param ...any - Values to write to output.
			]]function(...: any) end),

		read: typeof( --[[
				Yields the thread until `/input` is given.
				
				You can provide inputs in the code using `--@<input>` comments.
				
				@return string - The input provided by the user.
			]]function(): string
			return ""
		end),

		writefile: typeof( --[[
				Makes the log file output the content instead of log history with the specified file type.
				
				Supported file types: png, jpg, jpeg, gif, webp, svg, txt, ansi, lua, luau, json, xml, html, css, js, md, csv, mp3, wav, ogg, mp4, webm.
				If file type is not supported, defaults to ansi. This will also trigger the file to be sent.
				
				@param content string|buffer - The content to write to the file.
				@param filename string - The filename with extension.
				@return boolean - Whether the operation was successful.
			]]function(content: string, filename: string): boolean
			return true
		end),

		readfile: typeof( --[[
				Returns the currently loaded file's content and file type.
				
				@return string - The file content.
				@return string - The file type/extension.
			]]function(): (string, string)
			return "", ""
		end),

		getoutput: typeof( --[[
				Returns the current output log as a string.
				
				@return string - The current output log.
			]]function(): string
			return ""
		end),

		clearoutput: typeof( --[[
				Clears the output.
			]]function() end),
	}

	-- Misc Library type
	type misc = {
		truth: (vars: { any }) -> {},
		calculate: (vars: string, ...string) -> (),
		uwuify: (text: string) -> string,
	}

	-- Image Object types
	export type Image = {
		Size: Vector2,

		SetPixel: typeof( --[[
			Sets the pixel at the specified (x, y) coordinates to the given color and transparency.
			
			@param x number - The x coordinate of the pixel.
			@param y number - The y coordinate of the pixel.
			@param color Color3 - The color to set.
			@param transparency number - The transparency value (0-1).
			@param combineType Enum.ImageCombineType? - How the new color is combined with existing color. Default is Overwrite.
		]]function(
			self: Image,
			x: number,
			y: number,
			color: Color3,
			transparency: number,
			combineType: Enum.ImageCombineType?
		)
		end),

		GetPixel: typeof( --[[
			Returns the color and transparency of the pixel at the specified (x, y) coordinates.
			
			@param x number - The x coordinate of the pixel.
			@param y number - The y coordinate of the pixel.
			@return Color3 - The color of the pixel.
			@return number - The transparency of the pixel (0-1).
		]]function(self: Image, x: number, y: number): (Color3, number)
			return Color3.new(), 0
		end),

		Fill: typeof( --[[
			Fills the entire image with the specified color and transparency.
			
			@param color Color3 - The color to fill with.
			@param transparency number - The transparency value (0-1).
		]]function(self: Image, color: Color3, transparency: number) end),

		DrawRectangle: typeof( --[[
			Draws a rectangle at the specified position with the given size, color, and transparency.
			
			@param position Vector2 - The top-left position of the rectangle.
			@param size Vector2 - The size of the rectangle.
			@param color Color3 - The color of the rectangle.
			@param transparency number - The transparency value (0-1).
			@param combineType Enum.ImageCombineType? - How the new color is combined with existing colors. Default is Overwrite.
		]]function(
			self: Image,
			position: Vector2,
			size: Vector2,
			color: Color3,
			transparency: number,
			combineType: Enum.ImageCombineType?
		)
		end),

		DrawLine: typeof( --[[
			Draws a line from startPos to endPos with the specified color and transparency.
			
			@param startPos Vector2 - The starting position of the line.
			@param endPos Vector2 - The ending position of the line.
			@param color Color3 - The color of the line.
			@param transparency number - The transparency value (0-1).
			@param combineType Enum.ImageCombineType? - How the new color is combined with existing colors. Default is Overwrite.
		]]function(
			self: Image,
			startPos: Vector2,
			endPos: Vector2,
			color: Color3,
			transparency: number,
			combineType: Enum.ImageCombineType?
		)
		end),

		DrawCircle: typeof( --[[
			Draws a circle with the specified center, radius, color, and transparency.
			
			@param center Vector2 - The center position of the circle.
			@param radius number - The radius of the circle in pixels.
			@param color Color3 - The color of the circle.
			@param transparency number - The transparency value (0-1).
			@param combineType Enum.ImageCombineType? - How the new color is combined with existing colors. Default is Overwrite.
		]]function(
			self: Image,
			center: Vector2,
			radius: number,
			color: Color3,
			transparency: number,
			combineType: Enum.ImageCombineType?
		)
		end),

		DrawText: typeof( --[[
			Renders the specified text at the given position with color, transparency, and scale.
			
			The scale parameter accepts non-integer values (e.g., 1.5) and renders anti-aliased text using bilinear sampling.
			Note: Non-integer scales may result in slightly blurry/unreadable text. Invalid characters will be ignored.
			
			@param text string - The text to render.
			@param position Vector2 - The position to render the text.
			@param color Color3 - The color of the text.
			@param transparency number - The transparency value (0-1).
			@param scale number? - The scale multiplier for text size. Defaults to 1.
		]]function(
			self: Image,
			text: string,
			position: Vector2,
			color: Color3,
			transparency: number,
			scale: number?
		)
		end),

		DrawImageTransformed: typeof( --[[
			Draws another image onto this image at the specified position with scaling and rotation applied.
			
			@param position Vector2 - The position to draw the source image.
			@param scale Vector2 - The scale factor to apply (x, y).
			@param rotation number - The rotation angle in degrees.
			@param sourceImage Image - The source image to draw.
			@param options table? - Optional table containing:
				- CombineType: Enum.ImageCombineType - How images are combined. Default is AlphaBlend.
				- ResamplerMode: Enum.ResamplerMode - The resampling mode for scaling. Default is Bilinear.
				- PivotPoint: Vector2 - The pivot point for rotation in pixels. Default is size/2 of source image.
		]]function(
			self: Image,
			position: Vector2,
			scale: Vector2,
			rotation: number,
			sourceImage: Image,
			options: {
				CombineType: Enum.ImageCombineType?,
				ResamplerMode: Enum.ResamplerMode?,
				PivotPoint: Vector2?,
			}?
		)
		end),

		ReadPixelsBuffer: typeof( --[[
			Returns a buffer containing the raw pixel data of the image at the specified region.
			
			@param position Vector2 - The top-left position of the region.
			@param size Vector2 - The size of the region.
			@return buffer - The raw pixel data buffer.
		]]function(self: Image, position: Vector2, size: Vector2): buffer
			return buffer.create(0)
		end),

		WritePixelsBuffer: typeof( --[[
			Writes raw pixel data from a buffer to the image at the specified position and size.
			
			@param position Vector2 - The top-left position to write to.
			@param size Vector2 - The size of the region to write.
			@param pixelBuffer buffer - The raw pixel data buffer to write.
		]]function(self: Image, position: Vector2, size: Vector2, pixelBuffer: buffer) end),

		GetBuffer: typeof( --[[
			Returns the entire image's pixel data buffer.
			
			@return buffer - The entire image's raw pixel data.
		]]function(self: Image): buffer
			return buffer.create(0)
		end),

		Clone: typeof( --[[
			Creates and returns a copy of the Image object.
			
			@return Image - A new copy of the image.
		]]function(self: Image): Image
			return {} :: any
		end),
	}

	export type PlotOptions = {
		size: Vector2?,
		color: Color3?,
		thickness: number?,
		scale: number?,
		offset: Vector2?,
		showAxes: boolean?,
		showGrid: boolean?,
		showLabels: boolean?,
		axesColor: Color3?,
		gridColor: Color3?,
		labelColor: Color3?,
		gridSpacing: number?,
		labelSpacing: number?,
		labelSize: number?,
		isXFunction: boolean?,
		backgroundColor: Color3?,
		filename: string?,
	}

	export type GifOptions = {
		loop: number?,
	}

	type ImageLib = {
		new: (size: Vector2) -> Image,
		toPng: (image: Image, outputLogs: boolean?) -> string,
		toGif: (frames: { Image }, frameDelays: { number }, options: GifOptions?, outputLogs: boolean?) -> string,
		plotFunction: (func: (number) -> number, options: PlotOptions?) -> Image,
	}

	TIMEOUT = (TIMEOUT::any) :: TIMEOUT
	OUTPUT_LOGS = (OUTPUT_LOGS::any) :: OUTPUT_LOGS
	TIMESTAMP = (TIMESTAMP::any) :: TIMESTAMP
	native = (native::any) :: native
	optimize = (optimize::any) :: optimize

	bench = (bench::any) :: bench
	println = (println::any) :: println
	log = (log::any) :: log
	user = (user::any) :: user
	colorstring = (colorstring::any) :: colorstring

	etable = (etable::any) :: etable
	io = (io::any) :: io
	misc = (misc::any) :: misc
	Image = (Image::any) :: ImageLib
end
--[==[IGNORE END]==]
--The code above will be ignored during compilation.
--Put your code below this line
--    CODE HERE
------------------------
print("Hello World!")