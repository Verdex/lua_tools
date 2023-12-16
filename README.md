
# structuralize.lua

An implementation of structuralize patterns.

The majority of structuralize patterns are exactly what you would expect from ADT pattern matching or erlang style pattern matching.  You can capture sub sets of the input data in capture variables, permit arbitrary values with wildcards, and ensure that the 'structural' components match the pattern.

* `match(a, [1, 2, 3])` => `{ a => [1, 2, 3] }`
* `match([1, a, b, _], [1, 2, 3, 4])` => `{a => 2, b => 3}`

Things become more interesting when list path patterns are introduced:

* `match([| a, b |], [1, 2, 3, 4, 5])` => `[{a => 1, b => 2}, {a => 2, b => 3}, {a => 3, b => 4}, {a => 4, b => 5}]`

The list path pattern looks for all sub sections of the matched against list that match and then returns captures form all of the successful matches.

Path patterns are conceptually the same as list paths except they function on arbitrary structures.  List paths have a natural mechanism for deciding what to match against next.  Whatever is next in the list.  With an arbitrary structure you need to specify what ends up being next.

* `match( {| {a = ^, b = ^, c = 5}, { d = ^, e = ^ }, x |}, {a = { d = 1, e = 2 }, b = { d = 3, e = 4 }, c = 5} )`
    => `[{x => 1}, {x => 2}, {x => 3}, {x => 4}]`

You can also reference previously captured variables.

* `match( [a, $a], [1, 1] )` => `{ a => 1 }`

## lua syntax

While writing a parser for the structuralize patterns is an option, it hasn't been done yet (no planned timeline).  `structuralize.lua` exports several functions that allow you to construct patterns.

* `capture 'name'`
* `wild()`
* `pnext()`
* `path { p1, p2, p3, ... }`
* `list_path { p1, p2, p3, ... }`
* `exact { ... }`
* `match_with(f)`

`exact` is pulling double duty for matching an exact instance of a struct OR a list.  The idea here is that lua doesn't have structures or lists, but instead it has tables.  So `exact` is "match exact table", which is a super set of lists and structures.  Of course because tables in lua can have list-y elements AND structure-y elements at the same time, you can use `exact` to match against these types of objects as well.

`next` is already a native lua function, so I didn't want to collide with that pre-existing function with the definition of `pnext`.  

`to_dict` is also exported.  The output of the `match` function is a list of pairs of the form `{key, value}`.  Stuffing captures into a dictionary would have the effect of perserving only the last entry.  Searching for the first entry in a list would have the effect of perserving only the first entry.  By returning a list and a `to_dict` function that can convert the list into a dictionary, the consumer can decide which behavior makes more sense.

The rust implementation 'type-checks' patterns to ensure that multiple captures of the same name do not exist.  There's no reason the lua implementation couldn't do the same, but right now it doesn't.  The benefit of rust is that you can type-check once and then make sure nobody messes with the pattern to make it ill-typed.  Making sure the same is impossible in lua isn't as easy.

The `match_with` pattern pulls multiple duties depending on how you implement the `f` function.  `match` passes the current data being matched against to `f` as the first parameter and the current capture environment as the second paramater.  Changing either of these parameters will have unknown and likely detrimental effects on the matching algorithm.  The data parameter is almost definitely safe to save off, though, because the algorithm treats the data input immutabily.  However, the algorithm absolutely changes the capture environment, so pulling data from it should be safe, but holding onto the environment and expecting it to continue to make any sense after `f` is done being executed should be considered unsafe.

If you want the match to be successful then return `true` from `f` and otherwise return `false`.  However, you can also return a pattern.  If `f` returns a pattern then the algorithm will try to match it against the data.  Arbitrary patterns should be possible, but exhaustive testing hasn't been done.