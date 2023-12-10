-- Tested with lua 5.1

local function to_dict(t)
    local ret = {}
    for _, v in ipairs(t) do
        if type(v[1]) == "string" then
            ret[v[1]] = v[2]
        end
    end
    return ret
end

local function capture(name) return {name = name, type = "pattern", kind = "capture"} end
local function is_capture(t) return t.kind == "capture" end

local function wild() return {type = "pattern", kind = "wild"} end
local function is_wild(t) return t.kind == "wild" end

local function exact(t) return {table = t, type = "pattern", kind = "exact"} end
local function is_exact(t) return t.kind == "exact" end

local function list_path(t) return {table = t, type = "pattern", kind = "list_path"} end
local function is_list_path(t) return t.kind == "list_path" end

local function path(t) return {table = t, type = "pattern", kind = "path"} end
local function is_path(t) return t.kind == "path" end

local function pnext() return {type = "pattern", kind = "pnext"} end
local function is_pnext(t) return t.kind == "pnext" end

local function template(name) return {name = name, type = "pattern", kind = "template"} end
local function is_template(t) return t.kind == "template" end

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
    for _, v in ipairs(t) do
        if type(v[1]) == "nil" then
            -- successful match, but no capture
        elseif type(v[1]) == "string" then
            xs[#xs+1] = v
        elseif is_pnext(v[1]) then
            ns[#ns+1] = v
        else
            error("invalid split_pnext state")
        end
    end
    return ns, xs
end

local function match_exact(m, ps, data, env, index, results)
    index = index or 1
    results = results or {}
    if index > #ps then
        coroutine.yield(results)
        return true
    else
        local p = ps[index]
        local d = data[p[1]]
        local c = m(p[2], d, env)
        for output in c do
            if not output then 
                return false
            end
            if not match_exact(m, ps, data, env, index + 1, merge(results, output)) then
                return false
            end 
        end
        return true
    end
end

local function match_path(m, ps, data, env, index, results)
    index = index or 1
    results = results or {}
    if index > #ps then
        coroutine.yield(results)
        return true
    else
        local p = ps[index]
        local c = m(p, data, env)
        for output in c do
            if not output then
                return false
            end
            local nexts, normal = split_pnext(output)
            if #nexts == 0 then 
                coroutine.yield(merge(results, normal))
            else
                for _, v in ipairs(nexts) do
                    match_path(m, ps, v[2], env, index + 1, merge(results, normal))
                end
            end
        end
        return true
    end
end

local function match(pattern, data, env)
    assert(type(pattern) ~= "table" or pattern.type == "pattern")
    env = env or {}

    return coroutine.wrap(function() 
        if type(pattern) ~= "table" then
            if pattern == data then
                coroutine.yield({{}})
            else
                return false
            end
        elseif is_capture(pattern) then
            env[pattern.name] = data
            coroutine.yield({{pattern.name, data}})
        elseif is_wild(pattern) then
            coroutine.yield({{}})
        elseif is_exact(pattern) and type(data) == "table" then
            local lp = to_linear(pattern.table)
            local ld = to_linear(data)
            if #lp == #ld then
                if not match_exact(match, lp, data, env) then
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
                    match_exact(match, p, d, env)
                end
            else
                return false
            end
        elseif is_path(pattern) then
            match_path(match, pattern.table, data, env)
        elseif is_pnext(pattern) then
            coroutine.yield({{pattern, data}})
        elseif is_template(pattern) then
            local value = env[pattern.name]
            if type(value) == "table" then
                value = exact(value)
            end
            local res = match(value, data)
            if res() then
                coroutine.yield({{}})
            else 
                return false
            end
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
r = match(exact{capture 'x', 2, capture 'y'}, {1, 2, 3})
o = r()
assert(#o == 2)
o = to_dict(o)
assert(o.x == 1)
assert(o.y == 3)

-- should match structure
r = match(exact{x = capture 'x', y = 2, z = capture 'y'}, {x = 1, y = 2, z = 3})
o = r()
assert(#o == 2)
o = to_dict(o)
assert(o.y == 3)
assert(o.x == 1)

-- should match table
r = match(exact{x = capture 'x', y = 2, z = capture 'y', 4, 5, capture 'z'}, {x = 1, y = 2, z = 3, 4, 5, 6})
o = r()
assert(#o == 3)
o = to_dict(o)
assert(o.y == 3)
assert(o.x == 1)
assert(o.z == 6)

-- should match list list
r = match(exact{ exact{ capture 'x', capture 'y' }, capture 'z' }, { {1, 2}, 3 } )
o = r()
assert(#o == 3)
o = to_dict(o)
assert(o.y == 2)
assert(o.x == 1)
assert(o.z == 3)

-- should fail from unequal list length 
r = match(exact{ capture 'x', capture 'z' }, { 1, 2, 3 } )
o = r()
assert(not o)

-- should fail from incompatbile structure
r = match(exact{ x = 1, y = 2}, { x = 1, z = 2})
o = r()
assert(not o)

-- should fail in deeply nested pattern
r = match(exact{ 1, 2, exact{ 4, 5 }}, { 1, 2, { 4, 6 }})
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
r = match(exact{ list_path{capture 'x', 0}, list_path{capture 'y', 1} }, { {1, 0, 2, 5, 0}, {10, 1, 20, 50, 1} })
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
r = match(exact{ list_path{capture 'x', 0}, list_path{capture 'y', 1} }, { {1, 0, 2, 5, 0}, {9, 9, 9, 9, 9} })
o = r()
assert(not o)

-- should fail list path when data list is too short
r = match(list_path { capture 'x', 2, 3}, { 1 })
o = r()
assert(not o)

-- should match path
r = match(path{ exact{capture 'x', pnext(), 0, pnext(), capture 'y'}
              , exact{capture 'a', capture 'b', 0, pnext(), pnext()}
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

-- should match path in path with some failure branches
r = match( path { exact{ pnext(), pnext(), pnext() }, path { exact { pnext(), pnext() }, exact { capture 'a', 0 } } }, 
    { { { 5, 0 }, { 6, 0 } }, { { 10, 1 }, { 11, 1 } }, { { 99, 0 }, { 88, 1 } } })

o = r()
assert(#o == 1)
o = to_dict(o)
assert(o.a == 5)

o = r()
assert(#o == 1)
o = to_dict(o)
assert(o.a == 6)

o = r()
assert(#o == 1)
o = to_dict(o)
assert(o.a == 99)

o = r()
assert(not o)

-- should match path with failure cases
r = match(path{ exact{capture 'x', pnext(), 0, pnext(), capture 'y'}
              , exact{capture 'a', capture 'b', 0, pnext(), pnext()}
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
r = match(path{ exact{capture 'x', pnext(), 0, pnext(), capture 'y'}
              , exact{capture 'a', capture 'b', 0, pnext(), pnext()}
              , capture 'i' 
              },
           { 1, {10, 20, 0, 30, 40}, 9, {100, 200, 0, 300, 400}, 2 })

o = r()
assert(not o)

-- path should handle failure of one pnext branch
r = match(path { exact{ 1, pnext(), pnext() }, exact {1, capture 'a'} }, { 1, { 2, 3 }, { 1, 2 } } )

o = r()
assert(#o == 1)
o = to_dict(o)
assert(o.a == 2)

-- should succeed with zero captures in path
r = match(exact { path { exact { pnext(), pnext() }, 1 }, 0 }, { { 1, 1 }, 0 })
o = r()
assert(#o == 0)

-- path should fail when all pnext fail
r = match(exact { path { exact { pnext(), pnext() }, 1 }, 0 }, { { 2, 2 }, 0 })
o = r()
assert(not o)

-- should match path in list path
r = match(list_path{ path { exact{ pnext(), pnext() }, capture 'z' }, 
                     path { exact{ pnext(), pnext() }, capture 'w' } 
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

-- should fail match when template doesn't match
r = match(exact{ capture 'a', template 'a'}, {1, 2})

o = r()
assert(not o)

-- should fail match when template doesn't match
r = match(exact{ capture 'a', template 'a'}, {1, 2})

o = r()
assert(not o)

-- should match template
r = match(exact{ capture 'a', template 'a'}, {1, 1})

o = r()
assert(#o == 1)

o = to_dict(o)
assert(o.a == 1)

-- template should work inside list path
r = match(list_path{capture 'a', 0, template 'a'}, {1, 0, 2, 0, 2, 3, 0, 3, 9, 9, 9})

o = r()
assert(#o == 1)
o = to_dict(o)
assert(o.a == 2)

o = r()
assert(#o == 1)
o = to_dict(o)
assert(o.a == 3)

o = r()
assert(not o)

-- template should work inside path
r = match(path { exact{ 1, pnext(), pnext() }, exact {capture 'a', template 'a' } }, { 1, { 2, 3 }, { 4, 4 } } )

o = r()
assert(#o == 1)
o = to_dict(o)
assert(o.a == 4)

-- template variables should correctly transfer from list path to adjacent pattern in exact

-- template variables should correctly transfer from path to adjacent pattern in exact

-- template variables should match when captured value is a table
r = match( exact { capture 'a', template 'a' }, { { 1, 2, z = "a" }, { 1, 2, z = "a" } } )

o = r()
assert(#o == 1)
o = to_dict(o)
assert(o.a[1] == 1)
assert(o.a[2] == 2)
assert(o.a.z == "a")

-- multiple templates and captures should work
r = match(exact { capture 'a', capture 'b', template 'b', template 'a'}, {1, 2, 2, 1})

o = r()
assert(#o == 2)
o = to_dict(o)
assert(o.a == 1)
assert(o.b == 2)

--]]

return { to_dict = to_dict
       , capture = capture
       , wild = wild
       , pnext = pnext
       , path = path
       , list_path = list_path
       , exact = exact
       , match = match
       }