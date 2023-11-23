
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

--[[
local function product(cs, results) 
    results = results or {}
    if #cs ~= 0 then
        local c = table.remove(cs)
        for captures in c do
            if #captures ~= 0 then 
                product(cs, merge(results, captures))
            end
        end
    else
        coroutine.yield(results)
    end
end
--]]

local function match_exact(ps, data, results)
    results = results or {}
    if #ps == 0 then
        coroutine.yield(results)
    else
        local p = table.remove(ps)
        local d = table.remove(data)
        local c = match(p, d)
        for output in c do
            match_exact(ps, data, merge(results, output))
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
        elseif is_exact(pattern) and #pattern.table == #data then
            match_exact(pattern.table, data)
        else 
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



-- should match structure

-- should match table


print("ok")