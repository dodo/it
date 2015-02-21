local doc = require 'util.doc'

local _table = {}


function _table.weak(table)
    return setmetatable(table or {}, {
        __mode = 'k',
    })
end
doc.info(_table.weak, 'util_table.weak', '( table={} )')

function _table.readonly(table)
    return setmetatable({}, {
        __index = table,
        __newindex = function(table, key, value)
            error("attempt to modify read-only table")
        end,
        __metatable = false
    })
end
doc.info(_table.readonly, 'util_table.readonly', '( [table] )')

function _table.fake(name, table)
    name = name or '_'
    return setmetatable(table or {}, {
        __call = function ()
            if process.verbose then
                print(string.format("fake %s call", name))
            end
        end,
        __index = function (t,k)
            t[k] = _table.fake(name .. '.' .. k)
            return t[k]
        end
    })
end
doc.info(_table.fake, 'util_table.fake', '( name="_", table={} )')

function _table.sum(t1, t2)
    return _table.append(_table.copy(t1), t2)
end
doc.info(_table.sum, 'util_table.sum', '( table1, table2 )')

function _table.copy(t)
    return {unpack(t)}
end
doc.info(_table.copy, 'util_table.copy', '( table )')

function _table.slowcopy(t)
    local r = {}
    for k,v in pairs(t) do
        r[k] = v
    end
    return r
end
doc.info(_table.slowcopy, 'util_table.slowcopy', '( table )')

function _table.append(t1, t2)
    for i=1,#t2 do
        t1[#t1+1] = t2[i]
    end
    return t1
end
doc.info(_table.append, 'util_table.append', '( dst_table, src_table )')

function _table.update(t1, t2)
    for k,v in pairs(t2) do
        t1[k] = v
    end
    return t1
end
doc.info(_table.update, 'util_table.update', '( dst_table, src_table )')

function _table.index(t, val)
    for i, v in ipairs(t) do
        if v == val then
            return i
        end
    end
    return
end
doc.info(_table.index, 'util_table.index', '( table, value )')

function _table.deep_set(t, key, val)
    if not key:match('%.') then
        t[key] = val
        return
    end
--     print("------------",t)
    local v,k
    for w in key:gmatch('([_%w]+)%.?') do
        v,k = t[w],w
        print(v,k,t)
        if v then t = v else break end
    end
--     print("t[k] = val", t, k, val)
    t[k] = val
end
doc.info(_table.deep_set, 'util_table.deep_set', '( table, key, value )')

function _table.deep_get(t, key)
    local val = t
    for w in key:gmatch('([%w_]+)%.?') do
        val = val[w]
        if not val then break end
    end
    if val == t then val = val[key] end
    return val
end
doc.info(_table.deep_get, 'util_table.deep_get', '( table, key )')

function _table.format(s, t)
    for m in s:gmatch('{([%w_%.]+)}') do
        s, _ = s:gsub("{" .. m .. "}", _table.deep_get(t, m) or "")
    end
    return s
end
doc.info(_table.format, 'util_table.format', '( string, table )')


return _table
