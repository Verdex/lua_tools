-- Intended to work with lua 5.1

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
            prev = f(prev)
            coroutine.yield(prev)
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


--[[
local x = {11, 22, 33, 44, 55, 66, 77}

local z = from_list(x)

local output = z:map(function(y) return y + 1 end)
 :map(function(y) return y + 1 end)
 :map(function(y) return y + 1 end)
 :filter(function(y) return y % 2 == 0 end)
 :take(3)
 :skip(1)
 :eval()

for _, v in ipairs(output) do
    print(v)
end

output = from_previous(function(x) return x + 7 end, 8):take(100):reduce(function(a, b) return a + b end, 0)

print(output)
--]]