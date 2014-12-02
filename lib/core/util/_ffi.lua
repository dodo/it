local ffi = require 'ffi'
local doc = require 'util.doc'

local exports = {}


local function update(interface, values, opts)
    local changed = false
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
        changed = changed or (interface[key] ~= value)
        interface[key] = value
    end
    return interface, changed
end
exports.update = update
doc.info(update, 'util_ffi.update', '( interface, values, opts )')

function exports.convert_enum(key, value, typ, prefix)
    return update({}, {[key]=value}, {
        enums={[key]={typ=typ, prefix=prefix}}
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

function exports.metatype(name, metatable)
    metatable = metatable or {}
    metatable.__ipairs = metatable.__ipairs or require('inspect').ipairs
    metatable.__pairs  = metatable.__pairs  or require('inspect').pairs
    return ffi.metatype(name, metatable)
end
doc.info(exports.metatype, 'util_ffi.metatype', '( name, metatable={} )')

return exports
