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

local function iter(self)
    return self.c
end

local function create(t) 
    assert(t ~= nil)

    local c = coroutine.wrap(function () 
        for i in ipairs(t) do
            coroutine.yield(i)
        end
    end)

    return { type = "seq"
           , c = c
           , iter = iter
           , map = map 
           }
end


-- forever
-- take
-- filter
-- reduce
-- flatten


local x = {1, 2, 3, 4}

local z = create(x)

z:map(function(y) return y + 1 end)
 :map(function(y) return y + 1 end)
 :map(function(y) return y + 1 end)

for i in z:iter() do
    print(i)
end
