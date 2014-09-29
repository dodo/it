local exports = {}


function exports.bind(this, handler, ...)
    args = {...}
    return function (...) return handler(this, unpack(args), ...) end
end

function exports.ininterval(v, min, max)
    return v >= min and v <= max
end

function exports.constrain(v, min, max)
    if     v < min then
           v = min
    elseif v > max then
           v = max
    end
    return v
end

function exports.lerp(p, a, b)
    return (b - a) * p + a
end

function exports.table_index(t, val)
    for i, v in ipairs(t) do
        if v == val then
            return i
        end
    end
    return 0
end

function exports.table_deep_set(t, key, val)
    if not key:match('%.') then
        t[key] = val
        return
    end
    print("------------",t)
    local v,k
    for w in key:gmatch('([_%w]+)%.?') do
        v,k = t[w],w
        print(v,k,t)
        if v then t = v else break end
    end
    print("t[k] = val", t, k, val)
    t[k] = val
end

function exports.table_deep_get(t, key)
    local val = t
    for w in key:gmatch('([%w_]+)%.?') do
        val = val[w]
        if not val then break end
    end
    if val == t then val = val[key] end
    return val
end

function exports.table_format(s, t)
    for m in s:gmatch('{([%w_%.]+)}') do
        s, _ = s:gsub("{" .. m .. "}", exports.table_deep_get(t, m) or "")
    end
    return s
end

function exports.dump(t)
    local s = " -- \n"
    for k,v in pairs(t) do
        s = s .. tostring(k) .. " = " .. tostring(v) .. "\n"
    end
    return s
end

return exports
