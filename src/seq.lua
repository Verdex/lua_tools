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



--]]

return { from_repeat = from_repeat
       , from_previous = from_previous
       , from_list = from_list
       , from_index = from_index
       , from_iter = from_iter
       }
