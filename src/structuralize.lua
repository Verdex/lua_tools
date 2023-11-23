
local function to_dict(t)
    local ret = {}
    for _, v in ipairs(t) do
        if type(v[1]) == "string" then
            ret[v[1]] = v[2]
        end
    end
    return ret
end

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

local function exact_table(t)
    return {table = t, type = "pattern", kind = "exact_table"}
end

local function is_exact(t) 
    return t.kind == "exact_table"
end

local function merge(t1, t2)
    local r = {}
    for _, v in ipairs(t1) do
        r[#r + 1] = v
    end
    for _, v in ipairs(t2) do
        r[#r + 1] = v
    end
    return r
end

local function to_linear(t) 
    local ret = {}
    for k, v in pairs(t) do
        ret[#ret+1] = { k, v }
    end
    return ret
end

local function match_exact(m, ps, data, results)
    results = results or {}
    if #ps == 0 then
        coroutine.yield(results)
    else
        local p = table.remove(ps)
        local d = data[p[1]]
        local c = m(p[2], d)
        for output in c do
            match_exact(m, ps, data, merge(results, output))
        end
    end
end

local function match(pattern, data)
    assert(type(pattern) ~= "table" or pattern.type == "pattern")
    return coroutine.wrap(function() 
        if type(pattern) ~= "table" then
            coroutine.yield({{pattern == data, data}})
        elseif is_capture(pattern) then
            coroutine.yield({{pattern.name, data}})
        elseif is_wild(pattern) then
            coroutine.yield({{true, data}})
        elseif is_exact(pattern) and type(data) == "table" then
            local lp = to_linear(pattern.table)
            local ld = to_linear(data)
            if #lp == #ld then
                match_exact(match, lp, data)
            else 
                -- TODO fail
                error("todo fail case for exact")
            end
        else 
            print(#pattern.table, #data)
            -- TODO failure
            error("Unrecognized pattern")
        end

        -- path
        -- list path
        -- and/or ?
        -- matcher function ?
    end)
end


-- should capture
r = match(capture 'x', 40)
o = r()
assert(#o == 1)
assert(o[1][1] == 'x')
assert(o[1][2] == 40)

-- should match: nil, boolean, number, string
r = match(1, 1)
o = r()
assert(#o == 1)
assert(o[1][1])
assert(o[1][2] == 1)

r = match(nil, nil)
o = r()
assert(#o == 1)
assert(o[1][1])
assert(o[1][2] == nil)

r = match(false, false)
o = r()
assert(#o == 1)
assert(o[1][1])
assert(o[1][2] == false)

r = match("xstring", "xstring")
o = r()
assert(#o == 1)
assert(o[1][1])
assert(o[1][2] == "xstring")

-- should fail match: nil, boolean, number, string
r = match(2, 1)
o = r()
assert(#o == 1)
assert(not o[1][1])
assert(o[1][2] == 1)

r = match("", nil)
o = r()
assert(#o == 1)
assert(not o[1][1])
assert(o[1][2] == nil)

r = match(true, false)
o = r()
assert(#o == 1)
assert(not o[1][1])
assert(o[1][2] == false)

r = match("ystring", "xstring")
o = r()
assert(#o == 1)
assert(not o[1][1])
assert(o[1][2] == "xstring")

-- should match wild
r = match(wild(), { x = 1})
o = r()
assert(#o == 1)
assert(o[1][1])
assert(o[1][2].x == 1)

-- should match list
r = match(exact_table{capture 'x', 2, capture 'y'}, {1, 2, 3})
o = r()
assert(#o == 3)
assert(o[1][1] == "y")
assert(o[1][2] == 3)
assert(o[2][1])
assert(o[2][2] == 2)
assert(o[3][1] == "x")
assert(o[3][2] == 1)

-- should match structure
r = match(exact_table{x = capture 'x', y = 2, z = capture 'y'}, {x = 1, y = 2, z = 3})
o = r()
assert(#o == 3)
o = to_dict(o)
assert(o.y == 3)
assert(o.x == 1)

-- should match table
r = match(exact_table{x = capture 'x', y = 2, z = capture 'y', 4, 5, capture 'z'}, {x = 1, y = 2, z = 3, 4, 5, 6})
o = r()
assert(#o == 6)
o = to_dict(o)
assert(o.y == 3)
assert(o.x == 1)
assert(o.z == 6)

-- should match list list


-- should fail in deeply nested pattern

-- should fail in one path but succeed in others

print("ok")