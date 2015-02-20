local ffi = require 'ffi'
local doc = require 'util.doc'

local exports = {}

ffi.cdef[[
    void *calloc(size_t nmemb, size_t size);
]]

local function update(interface, values, opts)
    local changed = false
    for key,value in pairs(values) do
        if type(value) == 'string' then
            value = string.upper(value):gsub("%s", "_")
            if opts.enums and opts.enums[key] then
                value = (opts.prefix            or "") ..
                        (opts.enums[key].prefix or "") ..
                        value ..
                        (opts.enums[key].suffix or "") ..
                        (opts.suffix            or "")
                value = ffi.new(opts.enums[key].typ, value)
            end
        end
        changed = changed or (interface[key] ~= value)
        interface[key] = value
    end
    return interface, changed
end
exports.update = update
doc.info(update, 'util_ffi.update', '( interface, values, opts )')

function exports.convert_enum(key, value, typ, prefix, suffix)
    return update({}, {[key]=value}, {
        enums={[key]={typ=typ, prefix=prefix, suffix=suffix}}
    })[key]
end
doc.info(exports.convert_enum,
        'util_ffi.convert_enum',
        '( key, value, typ, prefix="" )')

function exports.enum_string(val, ct, prefix)
    local str = require('reflect').typeof(ct):value(val + 1).name
    if prefix == string.sub(str, 1 , string.len(prefix)) then
        str   =  string.sub(str, 1 + string.len(prefix))
    end
    return string.lower(str)--:gsub('_', ' ')
end
doc.info(exports.enum_string, 'util_ffi.enum_string', '( value, ct, prefix="" )')

function exports.ptraddr(ptr)
    return tonumber(ffi.cast('intptr_t', ffi.cast('void *', ptr)))
end
doc.info(exports.ptraddr, 'util_ffi.ptraddr', '( pointer )')

local __define
local function get_define(  )
    if not __define then
        __define = require('metatype'):fork():load('api', {
            define = 'it_defines_cdata_scope',
        }, require('cdef')):virt().define
    end
    return __define
end
exports.get_define = get_define
doc.private(get_define, 'util_ffi.get_define', '(  )')


local function lua_pushlightuserdata(name, pointer)
    -- insert into _D:
    get_define()(_D._it_scopes_, name, ffi.cast('void*', pointer))
end
exports.lua_pushlightuserdata = lua_pushlightuserdata
doc.info(lua_pushlightuserdata, 'util_ffi.lua_pushlightuserdata', '( name, pointer )')

local function tolightuserdata(pointer)
    local tmp_name = string.format("__tmp_userdata__%f",
        process.time() + math.random())
    lua_pushlightuserdata(tmp_name, pointer)
    local lightuserdata = _D[tmp_name]
    _D[tmp_name] = nil
    return lightuserdata
end
exports.tolightuserdata = tolightuserdata
doc.info(tolightuserdata, 'util_ffi.tolightuserdata', '( pointer )')

function exports.touserdata(pointer)
    local lightuserdata = pointer
    if type(pointer) == 'cdata' then
        lightuserdata = tolightuserdata(pointer)
    end
    return _it.holds(lightuserdata)
end
doc.info(exports.touserdata, 'util_ffi.touserdata', '( pointer )')

function exports.metatype(name, metatable)
    metatable = metatable or {}
    metatable.__ipairs = metatable.__ipairs or require('inspect').ipairs
    metatable.__pairs  = metatable.__pairs  or require('inspect').pairs
    return ffi.metatype(name, metatable)
end
doc.info(exports.metatype, 'util_ffi.metatype', '( name, metatable={} )')

function exports.new(ct, ...)
    local name, nelem, init = ct, 1, {...}
    if name:match('%[%?%]$') then
        name = name:match('^(.-)%[')
        nelem = init[1]
        table.remove(init, 1)
    end
    local cdata = ffi.cast(name..'*', ffi.C.calloc(nelem, ffi.sizeof(name)))
    assert(cdata ~= nil, "out of memory")
    return cdata
end
doc.info(exports.new, 'util_ffi.new', '( ct[,nelem] [,init...] )')

return exports
