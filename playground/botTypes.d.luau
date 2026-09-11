-- Bot API type definitions for luau-lsp autocomplete

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
export type PlotOptions = {
    offset: Vector2?,
    size: Vector2?,
    scale: number?,
    maxPixelSize: number?,
    isXFunction: boolean?,
    isParametric: boolean?,
    tRange: { number }?,
    color: { Color3 } | Color3?,
    backgroundColor: Color3?,
    showAxes: boolean?,
    axesColor: Color3?,
    showGrid: boolean?,
    gridColor: Color3?,
    gridSpacing: number?,
    showLabels: boolean?,
    labelColor: Color3?,
    labelSpacing: number?,
    labelSize: number?,
    thickness: number?,
    filename: string?,
}
export type GifOptions = {
    loop: number?,
}
declare class Image
    Size: Vector2
    function SetPixel(self, x: number, y: number, color: Color3, transparency: number, combineType: any?): ()
    function GetPixel(self, x: number, y: number): (Color3, number)
    function Fill(self, color: Color3, transparency: number): ()
    function DrawRectangle(self, position: Vector2, size: Vector2, color: Color3, transparency: number, combineType: any?): ()
    function DrawLine(self, startPos: Vector2, endPos: Vector2, color: Color3, transparency: number, combineType: any?): ()
    function DrawCircle(self, center: Vector2, radius: number, color: Color3, transparency: number, combineType: any?): ()
    function DrawText(self, text: string, position: Vector2, color: Color3, transparency: number, scale: number?): ()
    function DrawImageTransformed(self, position: Vector2, scale: Vector2, rotation: number, sourceImage: Image, options: { CombineType: any?, ResamplerMode: any?, PivotPoint: Vector2? }?): ()
    function ReadPixelsBuffer(self, position: Vector2, size: Vector2): buffer
    function WritePixelsBuffer(self, position: Vector2, size: Vector2, pixelBuffer: buffer): ()
    function GetBuffer(self): buffer
    function Clone(self): Image
    function Crop(self, position: Vector2, size: Vector2): Image
    function Resize(self, newSize: Vector2): Image
    function Grayscale(self): ()
    function Invert(self): ()
    function AdjustBrightness(self, amount: number): ()
    function AdjustContrast(self, factor: number): ()
    function AdjustSaturation(self, factor: number): ()
    function Tint(self, color: Color3, strength: number): ()
    function Threshold(self, cutoff: number?): ()
    function Blur(self, radius: number): ()
    function GaussianBlur(self, sigma: number): ()
    function Sharpen(self): ()
    function EdgeDetect(self): ()
    function Emboss(self): ()
    function Pixelate(self, blockSize: number): ()
    function Dither(self, levels: number?): ()
    function Posterize(self, levels: number): ()
    function ChromaticAberration(self, offset: number): ()
    function Vignette(self, strength: number): ()
    function FlipHorizontal(self): ()
    function FlipVertical(self): ()
    function Rotate90(self, times: number): ()
    function GetHistogram(self): { r: { number }, g: { number }, b: { number } }
    function AutoLevels(self): ()
    function Compare(self, otherImage: Image): Image
    function AlphaErode(self, threshold: number?): ()
end

-- Simple value globals
declare TIMEOUT: number
declare OUTPUT_LOGS: boolean
declare TIMESTAMP: boolean
declare native: boolean
declare optimize: number
declare user: { Name: string, UserId: number }

-- Global functions
declare function colorstring(text: string, color: string): string
declare function println(message: string, line: number?): number
declare function log(text: string, color: string, newLine: boolean?): ()
declare function bench(funcs: BenchFuncs | BenchFuncsWithParams, printMode: number?, iterations: number?, delayEveryXIter: number?): BenchResults
declare function ask(prompt: string, contextId: string?): string

-- Extended table library
declare etable: {
    getAllocatedArraySize: (tbl: { any }) -> number,
    getAllocatedHashSize: (tbl: { any }) -> number,
    getTableMemorySize: (tbl: { any }, includeContents: boolean?) -> number,
    getTableSize: (tbl: { any }, isContiguous: boolean?) -> number,
    mergeTables: (inPlace: boolean?, depth: number?, ...{ any }) -> { any },
    mergeTablesWith: (inPlace: boolean?, depth: number?, resolver: (key: any, value1: any, value2: any) -> any, ...{ any }) -> { any },
    accumulateTables: (inPlace: boolean?, ...{ any }) -> { any },
    diffTables: (old: { any }, new: { any }) -> { any },
    syncTable: (src: { any }, target: { any }) -> (),
    mapTable: <K, V, NK, NV>(tbl: { [K]: V }, callback: (key: K, value: V) -> (NK, NV)) -> { [NK]: NV },
    filterTable: <K, V>(tbl: { [K]: V }, predicate: (key: K, value: V) -> boolean, preAllocate: boolean?) -> { [K]: V },
    reduceTable: <K, V, R>(tbl: { [K]: V }, reducer: (accumulator: R, key: K, value: V) -> R, initial: R) -> R,
    groupTableBy: <K, V>(tbl: { [K]: V }, callback: (key: K, value: V) -> any) -> { [any]: { [K]: V } },
    tableToPairs: <K, V>(tbl: { [K]: V }) -> { { key: K, value: V } },
    invertTable: <K, V>(tbl: { [K]: V }) -> { [V]: K },
    tableIntersection: <K, V>(tbl1: { [K]: V }, tbl2: { [K]: V }, matchValue: boolean?) -> { [K]: V },
    tableDifference: <K, V>(tbl1: { [K]: V }, tbl2: { [K]: V }, matchValue: boolean?, symmetric: boolean?) -> { [K]: V },
    removeAll: (tbl: { any }, value: any) -> (),
    extendArraySize: (tbl: { any }, expandSize: number) -> (),
    setArraySize: (tbl: { any }, newSize: number) -> (),
    truncateArray: (array: { any }, newSize: number) -> (),
    concatArrays: (inPlace: boolean?, ...{ any }) -> { any },
    unionArrays: (...{ any }) -> { any },
    flattenArray: (src: { any }, depth: number?) -> { any },
    compactArray: (array: { any }, allocateExactSize: boolean?, isArray: boolean?) -> { any },
    fillWithValue: <T>(array: { T }, value: T, startIndex: number?, endIndex: number?, sourceArray: { T }?) -> (),
    fillWithPattern: <T>(array: { T }, pattern: { T }, startIndex: number?, endIndex: number?) -> (),
    reverseArray: <T>(array: { T }) -> (),
    rotateArray: <T>(array: { T }, shift: number) -> (),
    sliceArray: <T>(array: { T }, startIndex: number?, endIndex: number?) -> { T },
    shuffleArray: <T>(array: { T }) -> (),
    sampleArray: <T>(array: { T }, sampleSize: number, allowDuplicates: boolean?) -> { T },
    sampleValue: <T>(array: { T }, startIndex: number?, endIndex: number?) -> T,
    removeDuplicate: <T>(array: { T }, by: ((value: T) -> any)?) -> { T },
    swapRemove: <T>(array: { T }, index: number) -> T?,
    getAndRemove: <T>(array: { T }, index: number, swap: boolean?) -> T?,
    findAndRemove: <T>(array: { T }, value: T, swap: boolean?) -> boolean,
    zipArray: (...{ any }) -> { { any } },
    unzipArray: (zippedArray: { { any } }) -> ...{ any },
    partitionArray: <T>(array: { T }, size: number) -> { { T } },
    partitionArrayBy: <T>(array: { T }, predicate: (value: T) -> boolean) -> ({ T }, { T }),
    binarySearch: <T>(array: { T }, value: T, comparator: ((a: T, b: T) -> number)?) -> number?,
    getKeys: <K, V>(tbl: { [K]: V }) -> { K },
    getValues: <K, V>(tbl: { [K]: V }) -> { V },
    isContiguousArray: (tbl: { any }) -> boolean,
    isSparseArray: (tbl: { any }) -> boolean,
    isArray: (tbl: { any }) -> boolean,
    isEmpty: (tbl: { any }) -> boolean,
    hasKey: <K>(tbl: { [K]: any }, key: K) -> boolean,
    hasValue: <V>(tbl: { [any]: V }, value: V) -> boolean,
    countOccurences: <V>(tbl: { [any]: V }, value: V) -> number,
    countKeysByType: (tbl: { [any]: any }, keyType: string) -> number,
    countValuesByType: (tbl: { [any]: any }, valueType: string) -> number,
    keysOfValue: <K, V>(tbl: { [K]: V }, targetValue: V) -> { K },
    deepCopy: <T>(tbl: T) -> T,
    deepEqual: (a: any, b: any) -> boolean,
    deepFreeze: (tbl: { any }, layers: number?) -> (),
    findMatch: <K, V>(tbl: { [K]: V }, filter: (key: K, value: V) -> boolean) -> K?,
    every: <K, V>(tbl: { [K]: V }, filter: (key: K, value: V) -> boolean) -> boolean,
    some: <K, V>(tbl: { [K]: V }, filter: (key: K, value: V) -> boolean) -> boolean,
    toSet: <T>(tbl: { T }) -> { [T]: true },
}

-- IO library (bot-specific, overrides standard io)
declare io: {
    followupnext: () -> (),
    write: (...any) -> (),
    read: () -> string,
    writefile: (content: string | buffer, filename: string) -> boolean,
    readfile: (file: string) -> (string, string),
    getoutput: () -> string,
    clearoutput: () -> (),
}

-- Misc library
declare misc: {
    truth: (vars: { any }) -> {},
    calculate: (vars: string, ...string) -> (),
    uwuify: (text: string) -> string,
}

-- Image library (constructor + utilities)
type ImageLib = {
    new: (size: Vector2) -> Image,
    fromPng: (pngData: string) -> Image,
    toPng: (image: Image, outputLogs: boolean?) -> string,
    toGif: (frames: { Image }, frameDelays: { number }, options: GifOptions?, outputLogs: boolean?) -> string,
    plotFunction: (func: (number) -> number, options: PlotOptions?) -> Image,
}
declare Image: ImageLib

-- PacketSizeCounter library
declare PacketSizeCounter: {
    BaseRemoteOverhead: number,
    RemoteFunctionOverhead: number,
    ClientToServerOverhead: number,
    TypeOverhead: number,
    GetPacketSize: (counterData: {
        RunContext: "Server" | "Client",
        RemoteType: "RemoteEvent" | "RemoteFunction",
        PacketData: { any },
    }) -> number,
    GetDataByteSize: (data: any) -> number,
}
