

local function capture(name)
    return {name = name, type = "pattern", kind = "capture"}
end

local function is_capture(t)
    return t.kind == "capture"
end

local function wild() 
    return {type = "pattern", kind = "wild"}
end

local function is_wild(t)
    return t.kind == "wild"
end

local function match(pattern, data)
    assert(type(pattern) ~= "table" or pattern.type == "pattern")
    return coroutine.wrap(function() 
        if type(pattern) ~= "table" then
            coroutine.yield(pattern == data, data)
        elseif is_capture(pattern) then
            coroutine.yield(pattern.name, data)
        elseif is_wild(pattern) then
            coroutine.yield(true, data)
        -- table
        -- path
        -- list path
        -- and/or ?
        -- template ?
        -- pattern function ?
        -- matcher function ?
        end
    end)
end


-- should capture
r = match(capture 'x', 40)
a, b = r()
assert(a == 'x')
assert(b == 40)

-- should match: nil, boolean, number, string
r = match(1, 1)
a, b = r()
assert(a)
assert(b == 1)

r = match(nil, nil)
a, b = r()
assert(a)
assert(b == nil)

r = match(false, false)
a, b = r()
assert(a)
assert(b == false)

r = match("xstring", "xstring")
a, b = r()
assert(a)
assert(b == "xstring")

-- should fail match: nil, boolean, number, string
r = match(2, 1)
a, b = r()
assert(not a)
assert(b == 1)

r = match("", nil)
a, b = r()
assert(not a)
assert(b == nil)

r = match(true, false)
a, b = r()
assert(not a)
assert(b == false)

r = match("ystring", "xstring")
a, b = r()
assert(not a)
assert(b == "xstring")

-- should match wild
r = match(wild(), { x = 1})
a, b = r()
assert(a)
assert(b.x == 1)

print("ok")