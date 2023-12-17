-- Tested with lua 5.1

-- 2D Vec

local function dot2(self, v2)
    assert(type(v2) == "table" and v2.type == "vec2")
    return (self.x * v2.x) + (self.y * v2.y)
end

local function mag2(self)
    return math.sqrt((self.x * self.x) + (self.y * self.y))
end

local function mag2_sq(self)
    return (self.x * self.x) + (self.y * self.y)
end

local function add2(self, v2)
    assert(type(v2) == "table" and v2.type == "vec2")
    self.x = self.x + v2.x
    self.y = self.y + v2.y
    return self
end

local function add2_raw(self, x, y)
    self.x = self.x + x
    self.y = self.y + y
    return self
end

local function dist2(self, v2)
    assert(type(v2) == "table" and v2.type == "vec2")
    local x = v2.x - self.x
    local y = v2.y - self.y
    return math.sqrt((x * x) + (y * y))
end

local function dist2_sq(self, v2)
    assert(type(v2) == "table" and v2.type == "vec2")
    local x = v2.x - self.x
    local y = v2.y - self.y
    return (x * x) + (y * y)
end

local function dist2_sq_raw(self, x, y)
    local tx = x - self.x
    local ty = y - self.y
    return (tx * tx) + (ty * ty)
end

local function scale2(self, s)
    self.x = self.x * s
    self.y = self.y * s
    return self
end

local function rotate2(self, radians)
    local x = self.x
    local y = self.y

    self.x = (x * math.cos(radians)) - (y * math.sin(radians))
    self.y = (x * math.sin(radians)) + (y * math.cos(radians))

    return self
end

local function unit2(self)
    local m = self:mag()
    self:scale(1/m)
    return self
end

local vec2 = nil

local function clone2(self)
    return vec2(self.x, self.y)
end

vec2 = function(x, y)
    assert(type(x) == "number")
    assert(type(y) == "number")

    return { type = "vec2"
           , x = x
           , y = y
           , dot = dot2
           , mag = mag2
           , mag_sq = mag2_sq
           , add = add2
           , add_raw = add2_raw
           , dot = dot2
           , dist = dist2 
           , dist_sq = dist2_sq
           , dist_sq_raw = dist2_sq_raw
           , scale = scale2
           , rotate = rotate2
           , unit = unit2
           , clone = clone2
           }
end

---[[
do
    -- should clone
    local v = vec2(1, 2)
    local c = v:clone()
    assert(v.x == c.x)
    assert(v.y == c.y)
    c.x = 0
    c.y = 0
    assert(v.x == 1)
    assert(v.y == 2)
end

do
    -- should calculate dot product 
    local v1 = vec2(2, 3)
    local v2 = vec2(5, 7)
    local o = v1:dot(v2)
    assert(o == 31)
end

do
    -- should calculate magnitude
    local v = vec2(1, 1)
    local o = v:mag()
    assert(o == math.sqrt(2))
end

do
    -- should calculate magnitude squared
    local v = vec2(1, 1)
    local o = v:mag_sq()
    assert(o == 2)
end

do 
    -- should add
    local v1 = vec2(1, 2)
    local v2 = vec2(3, 4)
    local o = v1:add(v2)
    assert(o.x == 4)
    assert(o.y == 6)
end

do 
    -- should add raw
    local v1 = vec2(1, 2)
    local o = v1:add_raw(3, 4)
    assert(o.x == 4)
    assert(o.y == 6)
end

do
    -- should calculate distance
    local v1 = vec2(1, 1)
    local v2 = vec2(1, 3)
    local o = v1:dist(v2)
    assert(o == 2)
end

do
    -- should calculate distance squared
    local v1 = vec2(1, 1)
    local v2 = vec2(1, 3)
    local o = v1:dist_sq(v2)
    assert(o == 4)
end

do
    -- should calculate distance squared raw
    local v1 = vec2(1, 1)
    local o = v1:dist_sq_raw(1, 3)
    assert(o == 4)
end

do 
    -- should scale
    local v1 = vec2(1, 1)
    local o = v1:scale(2)
    assert(o.x == 2)
    assert(o.y == 2)
end

do
    -- should rotate
    local v1 = vec2(1, 0)
    local o = v1:rotate(math.pi / 2)
    assert(o.x < 0.0001)
    assert(o.y == 1)
end

do
    -- should create unit vector
    local v1 = vec2(1, 1)
    local o = v1:unit()
    assert(math.abs(o:mag() - 1) < 0.0001)
    local c = vec2(1, 1) -- note: v1 has been mutated
    local angle = math.acos(o:dot(c) / (o:mag() * c:mag()))
    assert(angle == 0)
end
--]]

return { vec2 = vec2
       }