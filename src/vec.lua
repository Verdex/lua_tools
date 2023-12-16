-- Tested with lua 5.1

local vec2 = nil

local function dot2(self, v2)
    assert(type(v2) == "table" and v2.type == "vec2")
    return (self.x * v2.x) + (self.y * v2.y)
end

local function mag(self)

end

local function mag_sq(self)

end

local function add2(self, v2)
    assert(type(v2) == "table" and v2.type == "vec2")
    return vec2(self.x + v2.x, self.y + v2.y)
end

local function add2_mut(self, v2)
end

local function add2_raw(self, x, y)
end

local function dist2(self, v2)
end

local function dist2_sq(self, v2)
end

local function dist2_sq_raw(self, x, y)
end
-- transform (probably shift and scale)


vec2 = function (x, y)
    assert(type(x) == "number")
    assert(type(y) == "number")

    return { type = "vec2"
           , x = x
           , y = y
           , dot = dot2
           , add = add2
           }
end

---[[
do
    local v1 = vec2(1, 2)
    local v2 = vec2(3, 4)
    local v3 = v1:add(v2)
    assert(v3.x == 4)
    assert(v3.y == 6)
end
--]]

return { vec2 = vec2
       }