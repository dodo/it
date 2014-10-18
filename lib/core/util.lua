local exports = {}
local util = exports

function exports.ignore_self(this, self, ...)
    -- if function is called with : on the same object
    return self == this and {...} or {self, ...}
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

function exports.readonlytable(table)
    return setmetatable({}, {
        __index = table,
        __newindex = function(table, key, value)
            error("attempt to modify read-only table")
        end,
        __metatable = false
    })
end

function exports.table_sum(t1, t2)
    return util.table_append(util.table_copy(t1), t2)
end

function exports.table_copy(t)
    return {unpack(t)}
end

function exports.table_append(t1, t2)
    for i=1,#t2 do
        t1[#t1+1] = t2[i]
    end
    return t1
end

function exports.table_index(t, val)
    for i, v in ipairs(t) do
        if v == val then
            return i
        end
    end
    return
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
        s, _ = s:gsub("{" .. m .. "}", util.table_deep_get(t, m) or "")
    end
    return s
end

function exports.update_ffi(interface, values, opts)
    local ffi = require 'ffi'
    for key,value in pairs(values) do
        if type(value) == 'string' then
            value = string.upper(value):gsub("%s", "_")
            if opts.enums and opts.enums[key] then
                value = (opts.prefix            or "") ..
                        (opts.enums[key].prefix or "") ..
                        value
                value = ffi.new(opts.enums[key].typ, value)
            end
        end
        interface[key] = value
    end
    return interface
end

function exports.convert_enum(key, value, typ, prefix)
    return tonumber(util.update_ffi({}, {[key]=value}, {
        enums={[key]={typ=typ, prefix=prefix}}
    })[key])
end

function exports.dump(t)
    local s = " -- \n"
    for k,v in pairs(t) do
        s = s .. tostring(k) .. " = " .. tostring(v) .. "\n"
    end
    return s
end


local table_sum, ignore_self = util.table_sum, util.ignore_self
function exports.bind(this, handler, ...)
    local args = this and {this, ...} or {...}
    if not this and #args == 0 then
        return handle
    elseif this and #args == 1 then
        return function (...)
            return handler(this, unpack(ignore_self(this, ...)))
        end
    elseif not this then
        return  function (...)
            return handler(unpack(table_sum(args, {...})))
        end
    else
        return  function (...)
            -- append copies of the arguments
            return handler(unpack(table_sum(args, ignore_self(this, ...))))
        end
    end
end

return exports
