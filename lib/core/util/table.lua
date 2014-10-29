local _table = {}


function _table.weak(table)
    return setmetatable(table, {
        __mode = 'k',
    })
end

function _table.readonly(table)
    return setmetatable({}, {
        __index = table,
        __newindex = function(table, key, value)
            error("attempt to modify read-only table")
        end,
        __metatable = false
    })
end

function _table.sum(t1, t2)
    return _table.append(_table.copy(t1), t2)
end

function _table.copy(t)
    return {unpack(t)}
end

function _table.append(t1, t2)
    for i=1,#t2 do
        t1[#t1+1] = t2[i]
    end
    return t1
end

function _table.index(t, val)
    for i, v in ipairs(t) do
        if v == val then
            return i
        end
    end
    return
end

function _table.deep_set(t, key, val)
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

function _table.deep_get(t, key)
    local val = t
    for w in key:gmatch('([%w_]+)%.?') do
        val = val[w]
        if not val then break end
    end
    if val == t then val = val[key] end
    return val
end

function _table.format(s, t)
    for m in s:gmatch('{([%w_%.]+)}') do
        s, _ = s:gsub("{" .. m .. "}", _table.deep_get(t, m) or "")
    end
    return s
end


return _table
