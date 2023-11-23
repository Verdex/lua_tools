-- Tested with lua 5.1

-- TODO remove
display = require 'display'

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

local function list_path(t)
    return {table = t, type = "pattern", kind = "list_path"}
end

local function is_list_path(t) 
    return t.kind == "list_path"
end

local function path(t) 
    return {table = t, type = "pattern", kind = "path"}
end

local function is_path(t)
    return t.kind == "path"
end

local function pnext()
    return {type = "pattern", kind = "pnext"}
end

local function is_pnext(t)
    return t.kind == "pnext"
end

local function merge(t1, t2)
    local r = {}
    for _, v in ipairs(t1) do
        if v[1] then
            r[#r + 1] = v
        end
    end
    for _, v in ipairs(t2) do
        if v[1] then
            r[#r + 1] = v
        end
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

local function split_pnext(t)
    local ns = {}
    local xs = {}
    for k, v in ipairs(t) do
        if type(v[1]) == "string" then
            xs[#xs+1] = v
        elseif is_pnext(v[1]) then
            ns[#ns+1] = v
        else
            error("invalid split_pnext state")
        end
    end
    return ns, xs
end

local function match_exact(m, ps, data, index, results)
    index = index or 1
    results = results or {}
    if index > #ps then
        coroutine.yield(results)
        return true
    else
        local p = ps[index]
        local d = data[p[1]]
        local c = m(p[2], d)
        for output in c do
            if not output then 
                return false
            end
            if not match_exact(m, ps, data, index + 1, merge(results, output)) then
                return false
            end 
        end
        return true
    end
end

local function match_path(m, ps, data, index, results)
    index = index or 1
    results = results or {}
    if index > #ps then
        coroutine.yield(results)
        return true
    else
        local p = ps[index]
        local c = m(p, data)
        for output in c do
            if not output then
                return false
            end
            local nexts, normal = split_pnext(output)
            if #nexts == 0 then 
                coroutine.yield(merge(results, normal))
            else
                for _, v in ipairs(nexts) do
                    if not match_path(m, ps, v[2], index + 1, merge(results, normal)) then
                        return false
                    end
                end
            end
        end
        return true
    end
end

local function match(pattern, data)
    assert(type(pattern) ~= "table" or pattern.type == "pattern")
    return coroutine.wrap(function() 
        if type(pattern) ~= "table" then
            if pattern == data then
                coroutine.yield({{}})
            else
                return false
            end
        elseif is_capture(pattern) then
            coroutine.yield({{pattern.name, data}})
        elseif is_wild(pattern) then
            coroutine.yield({{}})
        elseif is_exact(pattern) and type(data) == "table" then
            local lp = to_linear(pattern.table)
            local ld = to_linear(data)
            if #lp == #ld then
                if not match_exact(match, lp, data) then
                    return false
                end
            else 
                return false
            end
        elseif is_list_path(pattern) and type(data) == "table" then
            if #pattern.table <= #data then
                for i = 1, 1 + #data - #pattern.table do
                    local p = to_linear(pattern.table)
                    local d = {unpack(data, i, i + #pattern.table)}
                    -- TODO maybe need to return false if EVERY match_exact returns false
                    match_exact(match, p, d)
                end
            else
                return false
            end
        elseif is_path(pattern) then
            match_path(match, pattern.table, data)
        elseif is_pnext(pattern) then
            coroutine.yield({{pattern, data}})
        else 
            return false
        end
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
assert(#o[1] == 0)

r = match(nil, nil)
o = r()
assert(#o == 1)
assert(#o[1] == 0)

r = match(false, false)
o = r()
assert(#o == 1)
assert(#o[1] == 0)

r = match("xstring", "xstring")
o = r()
assert(#o == 1)
assert(#o[1] == 0)

-- should fail match: nil, boolean, number, string
r = match(2, 1)
o = r()
assert(not o)

r = match("", nil)
o = r()
assert(not o)

r = match(true, false)
o = r()
assert(not o)

r = match("ystring", "xstring")
o = r()
assert(not o)

-- should match wild
r = match(wild(), { x = 1})
o = r()
assert(#o == 1)
assert(#o[1] == 0)

-- should match list
r = match(exact_table{capture 'x', 2, capture 'y'}, {1, 2, 3})
o = r()
assert(#o == 2)
o = to_dict(o)
assert(o.x == 1)
assert(o.y == 3)

-- should match structure
r = match(exact_table{x = capture 'x', y = 2, z = capture 'y'}, {x = 1, y = 2, z = 3})
o = r()
assert(#o == 2)
o = to_dict(o)
assert(o.y == 3)
assert(o.x == 1)

-- should match table
r = match(exact_table{x = capture 'x', y = 2, z = capture 'y', 4, 5, capture 'z'}, {x = 1, y = 2, z = 3, 4, 5, 6})
o = r()
assert(#o == 3)
o = to_dict(o)
assert(o.y == 3)
assert(o.x == 1)
assert(o.z == 6)

-- should match list list
r = match(exact_table{ exact_table{ capture 'x', capture 'y' }, capture 'z' }, { {1, 2}, 3 } )
o = r()
assert(#o == 3)
o = to_dict(o)
assert(o.y == 2)
assert(o.x == 1)
assert(o.z == 3)

-- should fail from unequal list length 
r = match(exact_table{ capture 'x', capture 'z' }, { 1, 2, 3 } )
o = r()
assert(not o)

-- should fail from incompatbile structure
r = match(exact_table{ x = 1, y = 2}, { x = 1, z = 2})
o = r()
assert(not o)

-- should fail in deeply nested pattern
r = match(exact_table{ 1, 2, exact_table{ 4, 5 }}, { 1, 2, { 4, 6 }})
o = r()
assert(not o)

-- should match list path
r = match(list_path{capture 'x', capture 'y'}, { 1, 2, 3, 4, 5})
o = r()
assert(#o == 2)
o = to_dict(o)
assert(o.x == 1)
assert(o.y == 2)

o = r()
assert(#o == 2)
o = to_dict(o)
assert(o.x == 2)
assert(o.y == 3)

o = r()
assert(#o == 2)
o = to_dict(o)
assert(o.x == 3)
assert(o.y == 4)

o = r()
assert(#o == 2)
o = to_dict(o)
assert(o.x == 4)
assert(o.y == 5)

o = r()
assert(o == nil)

-- should match inner list path
r = match(exact_table{ list_path{capture 'x', 0}, list_path{capture 'y', 1} }, { {1, 0, 2, 5, 0}, {10, 1, 20, 50, 1} })
o = r()
assert(#o == 2)
o = to_dict(o)
assert(o.x == 1)
assert(o.y == 10)

o = r()
assert(#o == 2)
o = to_dict(o)
assert(o.x == 1)
assert(o.y == 50)

o = r()
assert(#o == 2)
o = to_dict(o)
assert(o.x == 5)
assert(o.y == 10)

o = r()
assert(#o == 2)
o = to_dict(o)
assert(o.x == 5)
assert(o.y == 50)

o = r()
assert(not o)

-- should fail complete match when sub list path match completely fails
r = match(exact_table{ list_path{capture 'x', 0}, list_path{capture 'y', 1} }, { {1, 0, 2, 5, 0}, {9, 9, 9, 9, 9} })
o = r()
assert(not o)

-- should fail list path when data list is too short
r = match(list_path { capture 'x', 2, 3}, { 1 })
o = r()
assert(not o)

-- should match path
r = match(path{ exact_table{capture 'x', pnext(), 0, pnext(), capture 'y'}
              , exact_table{capture 'a', capture 'b', 0, pnext(), pnext()}
              , capture 'i' 
              },
           { 1, {10, 20, 0, 30, 40}, 0, {100, 200, 0, 300, 400}, 2 })

o = r()
assert(#o == 5)
o = to_dict(o)
assert(o.x == 1)
assert(o.y == 2)
assert(o.a == 10)
assert(o.b == 20)
assert(o.i == 30)

o = r()
assert(#o == 5)
o = to_dict(o)
assert(o.x == 1)
assert(o.y == 2)
assert(o.a == 10)
assert(o.b == 20)
assert(o.i == 40)

o = r()
assert(#o == 5)
o = to_dict(o)
assert(o.x == 1)
assert(o.y == 2)
assert(o.a == 100)
assert(o.b == 200)
assert(o.i == 300)

o = r()
assert(#o == 5)
o = to_dict(o)
assert(o.x == 1)
assert(o.y == 2)
assert(o.a == 100)
assert(o.b == 200)
assert(o.i == 400)

o = r()
assert(not o)


-- should match path with failure cases
r = match(path{ exact_table{capture 'x', pnext(), 0, pnext(), capture 'y'}
              , exact_table{capture 'a', capture 'b', 0, pnext(), pnext()}
              , capture 'i' 
              },
           { 1, {10, 20, 0, 30, 40}, 0, {100, 200, 9, 300, 400}, 2 })

o = r()
assert(#o == 5)
o = to_dict(o)
assert(o.x == 1)
assert(o.y == 2)
assert(o.a == 10)
assert(o.b == 20)
assert(o.i == 30)

o = r()
assert(#o == 5)
o = to_dict(o)
assert(o.x == 1)
assert(o.y == 2)
assert(o.a == 10)
assert(o.b == 20)
assert(o.i == 40)

o = r()
assert(not o)

-- should fail path 
r = match(path{ exact_table{capture 'x', pnext(), 0, pnext(), capture 'y'}
              , exact_table{capture 'a', capture 'b', 0, pnext(), pnext()}
              , capture 'i' 
              },
           { 1, {10, 20, 0, 30, 40}, 9, {100, 200, 0, 300, 400}, 2 })

o = r()
assert(not o)

-- should match path in list path
r = match(list_path{ path { exact_table{ pnext(), pnext() }, capture 'z' }, 
                     path { exact_table{ pnext(), pnext() }, capture 'w' } 
                   },
         { { 1, 2 }, { 3, 4 }, { 5, 6 } })

o = r()
assert(#o == 2)
o = to_dict(o)
assert(o.z == 1)
assert(o.w == 3)

o = r()
assert(#o == 2)
o = to_dict(o)
assert(o.z == 1)
assert(o.w == 4)

o = r()
assert(#o == 2)
o = to_dict(o)
assert(o.z == 2)
assert(o.w == 3)

o = r()
assert(#o == 2)
o = to_dict(o)
assert(o.z == 2)
assert(o.w == 4)

o = r()
assert(#o == 2)
o = to_dict(o)
assert(o.z == 3)
assert(o.w == 5)

o = r()
assert(#o == 2)
o = to_dict(o)
assert(o.z == 3)
assert(o.w == 6)

o = r()
assert(#o == 2)
o = to_dict(o)
assert(o.z == 4)
assert(o.w == 5)

o = r()
assert(#o == 2)
o = to_dict(o)
assert(o.z == 4)
assert(o.w == 6)

o = r()
assert(not o)

-- should match list path in path
r = match(path{ list_path{ pnext(), pnext() }, capture 'x' },
         { 1, 2, 3, 4, 5, 6 })

-- TODO exact_table => exact
o = r()
assert(#o == 1)
o = to_dict(o)
assert(o.x == 1)

o = r()
assert(#o == 1)
o = to_dict(o)
assert(o.x == 2)

o = r()
assert(#o == 1)
o = to_dict(o)
assert(o.x == 2)

o = r()
assert(#o == 1)
o = to_dict(o)
assert(o.x == 3)

o = r()
assert(#o == 1)
o = to_dict(o)
assert(o.x == 3)

o = r()
assert(#o == 1)
o = to_dict(o)
assert(o.x == 4)

o = r()
assert(#o == 1)
o = to_dict(o)
assert(o.x == 4)

o = r()
assert(#o == 1)
o = to_dict(o)
assert(o.x == 5)

o = r()
assert(#o == 1)
o = to_dict(o)
assert(o.x == 5)

o = r()
assert(#o == 1)
o = to_dict(o)
assert(o.x == 6)

o = r()
assert(not o)

print("ok")
