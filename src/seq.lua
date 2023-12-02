-- Tested with lua 5.1

local function map(self, f)
    assert(f ~= nil)

    local c = self.c
    self.c = coroutine.wrap(function() 
        for i in c do
            coroutine.yield(f(i))
        end
    end)

    return self
end

local function filter(self, p)
    assert(p ~= nil)

    local c = self.c
    self.c = coroutine.wrap(function() 
        for i in c do
            if p(i) then
                coroutine.yield(i)
            end
        end
    end)

    return self
end

local function take(self, num)
    assert(num >= 0)

    local c = self.c
    self.c = coroutine.wrap(function() 
        for i in c do
            if num < 1 then 
                break
            end
            num = num - 1
            coroutine.yield(i)
        end
    end)

    return self
end

local function skip(self, num)
    assert(num >= 0)

    local c = self.c
    self.c = coroutine.wrap(function() 
        for i in c do
            if num <= 0 then 
                coroutine.yield(i)
            else
                num = num - 1
            end
        end
    end)

    return self
end

local function reduce(self, f, start)
    assert(f ~= nil and start ~= nil)

    local sum = start
    for i in self:iter() do
        sum = f(sum, i)
    end

    return sum
end

local function eval(self) 
    local t = {}
    for i in self:iter() do
        t[#t+1] = i
    end
    return t
end

local function iter(self)
    return self.c
end

local function create(c)
    return { type = "seq"
           , c = c
           , iter = iter
           , map = map 
           , filter = filter
           , take = take
           , skip = skip
           , reduce = reduce
           , eval = eval
           }
end

local function from_list(t) 
    assert(t ~= nil)

    local c = coroutine.wrap(function () 
        for _, v in ipairs(t) do
            coroutine.yield(v)
        end
    end)

    return create(c) 
end

local function from_index(f, start) 
    assert(f ~= nil)
    start = start or 1

    local c = coroutine.wrap(function () 
        while true do
            coroutine.yield(f(start))
            start = start + 1
        end
    end)

    return create(c) 
end

local function from_previous(f, start) 
    assert(f ~= nil and start ~= nil)

    local c = coroutine.wrap(function () 
        local prev = start
        while true do
            coroutine.yield(prev)
            prev = f(prev)
        end
    end)

    return create(c) 
end

local function from_repeat(r) 
    assert(r ~= nil)

    local c = coroutine.wrap(function () 
        while true do
            coroutine.yield(r)
        end
    end)

    return create(c) 
end

local function from_iter(i)
    assert(i ~= nil)

    local c = coroutine.wrap(function () 
        for ilet in i do 
            coroutine.yield(ilet)
        end
    end)

    return create(c) 
end

---[[

-- should repeat
local x = from_repeat(1):take(5):eval()
assert(#x == 5)
assert(x[1] == 1)
assert(x[2] == 1)
assert(x[3] == 1)
assert(x[4] == 1)
assert(x[5] == 1)

-- should index
local x = from_index(function(i) return i end, 1):take(5):eval()
assert(#x == 5)
assert(x[1] == 1)
assert(x[2] == 2)
assert(x[3] == 3)
assert(x[4] == 4)
assert(x[5] == 5)

-- should compute from previous
local x = from_previous(function(i) return i + 1 end, 1):take(5):eval()
assert(#x == 5)
assert(x[1] == 1)
assert(x[2] == 2)
assert(x[3] == 3)
assert(x[4] == 4)
assert(x[5] == 5)

-- should from_iter an iter of a from_list
local x = from_iter(from_list({1, 2, 3, 4, 5}):iter()):eval()
assert(#x == 5)
assert(x[1] == 1)
assert(x[2] == 2)
assert(x[3] == 3)
assert(x[4] == 4)
assert(x[5] == 5)

-- should map
local x = from_list({1, 2, 3, 4, 5}):map(function(x) return x + 1 end):eval()
assert(#x == 5)
assert(x[1] == 2)
assert(x[2] == 3)
assert(x[3] == 4)
assert(x[4] == 5)
assert(x[5] == 6)

-- should skip
local x = from_list({1, 2, 3, 4, 5}):skip(2):eval()
assert(#x == 3)
assert(x[1] == 3)
assert(x[2] == 4)
assert(x[3] == 5)

-- should filter
local x = from_list({1, 2, 3, 4, 5}):filter(function(i) return i % 2 == 0 end):eval()
assert(#x == 2)
assert(x[1] == 2)
assert(x[2] == 4)

-- should reduce
local x = from_list({1, 2, 3, 4, 5}):reduce(function(a, b) return a + b end, 1)
assert(x == 16)

--]]

return { from_repeat = from_repeat
       , from_previous = from_previous
       , from_list = from_list
       , from_index = from_index
       , from_iter = from_iter
       }
