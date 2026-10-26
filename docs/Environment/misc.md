
Some random functions.

### `truth(vars:{any}):{}`
creates a truth table for the given variables

### `inspect(value:any):{}`
Estimates how much memory a value takes. `shallowBytes` is the value's own storage, and `estimatedTotalBytes` adds the table keys and values and visible Instance descendants it reaches. Shared objects count once, and cycles are fine.

The result also has the TValue layout, table capacities, closure, class, object and Instance layouts, and summaries of metatables that aren't protected. For tables, `entries` holds up to 64 key/value summaries.

```lua
local info = misc.inspect({1, 2, child = {3}})
print(info.shallowBytes, info.estimatedTotalBytes)
```

- Instance estimates only count the known base and userdata, so `estimatePartial` is true when the estimate is incomplete.
- Traversal stops after 10,000 references and sets `truncated` to true.
- Totals leave out metatables, shared prototypes, class member graphs, function captures and allocator overhead.

### `calculate(vars:string,...string})`
calculates the given boolean expression with the given variables and outputs it.

example:
```lua
misc.calculate("pq", "~p v q", "p ^ q", "p -> q", "p <-> q")
```

### `uwuify(text:string):string`
Hi

