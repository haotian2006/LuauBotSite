
The default table library has extended functions provided by Akari <3. 
These just provide a few gimmicky functions on top of the default table library.


```lua
local t = {1,2,3,4,5,6,7,8,9}
print(etable.getAllocatedArraySize(t)) --> 9
t[10] = 10
print(etable.getAllocatedArraySize(t)) --> 16

print(etable.concat(t, ", ")) --> 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 
```

This extends the default table library in Luau with additional utility functions.
<span style="font-size: 70%;">[source](https://github.com/Akari-yn/ExtendedTableLibrary/tree/main)</span>

### `getAllocatedArraySize(tbl: table)`
Returns the allocated size of a Luau table's array part.

### `getAllocatedHashSize(tbl: table)`
Returns the allocated size of a Luau table's hash part.

### `getTableMemorySize(tbl: table, includeContents: boolean?)`
Returns the total memory used by a table, optionally including contents.

### `getTableSize(tbl: table, isContiguous: boolean?)`
Counts the number of elements in a table. Optimized for contiguous arrays.

### `mergeTables(inPlace: boolean?, depth: number?, ...tables: table)`
Recursively merges tables, combining their keys and values.

### `mergeTablesWith(inPlace: boolean?, depth: number?, resolver: function, ...tables: table)`
Recursively merges tables with a custom resolver for conflicts.

### `accumulateTables(inPlace: boolean?, ...tables: table)`
Recursively combines tables by summing matching numeric values and merging nested tables.

### `diffTables(old: table, new: table)`
Compares two tables and returns a breakdown of differences.

### `syncTable(src: table, target: table)`
Synchronizes the keys and values of a source table with a target table.

### `mapTable(tbl: table, callback: function)`
Creates a new table by applying a callback to each key-value pair.

### `filterTable(tbl: table, predicate: function, preAllocate: boolean?)`
Creates a new table containing only key-value pairs that satisfy the predicate.

### `reduceTable(tbl: table, reducer: function, initial: any)`
Reduces a table to a single value by applying a reducer function.

### `groupTableBy(tbl: table, callback: function)`
Groups the elements of a table by a specified key or property.

### `tableToPairs(tbl: table)`
Converts a table into an array of key-value pairs.

### `invertTable(tbl: table)`
Inverts a table, swapping its keys and values.

### `tableIntersection(tbl1: table, tbl2: table, matchValue: boolean?)`
Finds the intersection of two tables.

### `tableDifference(tbl1: table, tbl2: table, matchValue: boolean?, symmetric: boolean?)`
Finds the difference between two tables.

### `removeAll(tbl: table, value: any | array)`
Removes all occurrences of a specified value from a table.

### `extendArraySize(tbl: table, expandSize: number)`
Extends an array by a given size.

### `setArraySize(tbl: table, newSize: number)`
Sets the length of an array to a new size (only expands).

### `truncateArray(array: array, newSize: number)`
Truncates an array to a specified size.

### `concatArrays(inPlace: boolean?, ...arrays: array)`
Concatenates multiple arrays into a single array.

### `unionArrays(...arrays: array)`
Creates a new array with all unique elements from the input arrays.

### `flattenArray(src: array, depth: number?)`
Recursively flattens a nested array up to a given depth.

### `compactArray(array: array, allocateExactSize: boolean?, isArray: boolean?)`
Compacts a sparse array into a contiguous array.

### `fillWithValue(array: array, value: any, startIndex: number?, endIndex: number?, sourceArray: array?)`
Fills an array with a specified value from start to end index.

### `fillWithPattern(array: array, pattern: array, startIndex: number?, endIndex: number?)`
Fills an array with values from a source array, repeating the pattern as needed.

### `reverseArray(array: array)`
Reverses the order of elements in an array in place.

### `rotateArray(array: array, shift: number)`
Rotates the elements of an array by a specified number of positions.

### `sliceArray(array: array, startIndex: number?, endIndex: number?)`
Creates a new array containing a portion of the original array.

### `shuffleArray(array: array)`
Randomly shuffles the elements of an array in place.

### `sampleArray(array: array, sampleSize: number, allowDuplicates: boolean?)`
Randomly selects a specified number of elements from an array.

### `sampleValue(array: array, startIndex: number?, endIndex: number?)`
Randomly selects a single value from an array.

### `removeDuplicate(array: array, by: function?)`
Removes duplicate values from an array, preserving order.

### `swapRemove(array: array, index: number)`
Removes an element from an array at a specified index using swap-remove.

### `getAndRemove(array: array, index: number, swap: boolean?)`
Retrieves and removes an element from an array at a specified index.

### `findAndRemove(array: array, value: any, swap: boolean?)`
Finds the first occurrence of a value in an array and removes it.

### `zipArray(...arrays: array)`
Combines multiple arrays into a single array of tuples.

### `unzipArray(zippedArray: array)`
Reverses the operation of `zipArray`.

### `partitionArray(array: array, size: number)`
Splits an array into smaller arrays of a specified size.

### `partitionArrayBy(array: array, predicate: function)`
Splits an array into two arrays based on a predicate function.

### `binarySearch(array: array, value: any, comparator: function?)`
Performs a binary search on a sorted array.

### `getKeys(tbl: table)`
Retrieves the keys of a table as an array.

### `getValues(tbl: table)`
Retrieves the values of a table as an array.

### `isContiguousArray(tbl: table)`
Checks if a table is a contiguous array.

### `isSparseArray(tbl: table)`
Checks if a table is a sparse array.

### `isArray(tbl: table)`
Checks if a table is an array (only positive integer keys).

### `isEmpty(tbl: table)`
Checks if a table is empty.

### `hasKey(tbl: table, key: any)`
Checks if a table contains a specific key.

### `hasValue(tbl: table, value: any)`
Checks if a table contains a specific value.

### `countOccurences(tbl: table, value: any)`
Counts the number of occurrences of a specific value in a table.

### `countKeysByType(tbl: table, keyType: string)`
Counts the number of keys in a table that match a specific type.

### `countValuesByType(tbl: table, valueType: string)`
Counts the number of values in a table that match a specific type.

### `keysOfValue(tbl: table, targetValue: any)`
Retrieves all keys in a table that map to a specific value.

### `deepCopy(tbl: table)`
Creates a recursive, deep copy of a table.

### `deepEqual(a: any, b: any)`
Recursively compares two values for equality, handling nested tables.

### `deepFreeze(tbl: table, layers: number?)`
Recursively freezes a table and its nested tables.

### `findMatch(tbl: table, filter: function)`
Finds the first key in a table that satisfies the given filter function.

### `every(tbl: table, filter: function)`
Checks if every key-value pair in a table satisfies the filter function.

### `some(tbl: table, filter: function)`
Checks if at least one key-value pair in a table satisfies the filter function.

### `toSet(tbl: table)`
Converts a table into a set (all keys map to true).

### `prettyPrint(tbl: table, indent: number?)`
Converts a table into a human-readable string format.

### `toCSV(rows: array, delimiter: string?)`
Converts a 2D array into a CSV string format.
