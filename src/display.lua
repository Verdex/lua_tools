-- Tested with lua 5.1

local function pd(t, pad, assign) 
    pad = pad or 0
    if type(t) == "string" then
        -- TODO: include escapes?
        if assign then
            return string.format('"%s"', t)
        else
            return string.rep(' ', 4 * pad) .. string.format('"%s"', t)
        end
    elseif type(t) ~= "table" then
        if assign then
            return tostring(t)
        else
            return string.rep(' ', 4 * pad) .. tostring(t)
        end
    else 
        local r = {}
        for k, v in pairs(t) do
            if type(k) == "number" then
                r[#r+1] = pd(v, pad + 1)
            else
                r[#r+1] = pd(k, pad + 1) .. " = " .. pd(v, pad + 1, true)
            end
        end
        if #r == 0 then
            return "{}"
        end
        local space = string.rep(' ', 4 * pad)
        if assign then
            return string.format("{\n%s\n%s}", table.concat(r, ",\n"), space)
        else
            return string.format("%s{\n%s\n%s}", space, table.concat(r, ",\n"), space)
        end
    end
end

local function pp(t)
    print(pd(t))
end


return { pp = pp, pd = pd }