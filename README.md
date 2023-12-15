
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