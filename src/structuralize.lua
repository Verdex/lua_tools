

local function capture(name)
    return {name = name, type = "pattern", kind = "capture"}
end

local function is_capture(t)
    return type(t) == "table" 
       and t.type == "pattern" 
       and t.kind == "capture"
end

local function match(pattern, data)
    return coroutine.wrap(function() 
        if is_capture(pattern) then
            coroutine.yield(pattern.name, data)
        elseif type(pattern) ~= "table" then
            coroutine.yield(pattern == data, data)
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

print("ok")