local ffi = require 'ffi'

local exports = {}


local function update(interface, values, opts)
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
exports.update = update

function exports.convert_enum(key, value, typ, prefix)
    return update({}, {[key]=value}, {
        enums={[key]={typ=typ, prefix=prefix}}
    })[key]
end

function exports.enum_string(val, ct, prefix)
    local str = require('reflect').typeof(ct):value(val + 1).name
    if prefix == string.sub(str, 1 , string.len(prefix)) then
        str   =  string.sub(str, 1 + string.len(prefix))
    end
    return string.lower(str)--:gsub('_', ' ')
end

function exports.ptraddr(ptr)
    return tonumber(ffi.cast('intptr_t', ffi.cast('void *', ptr)))
end

function exports.metatype(name, metatable)
    metatable = metatable or {}
    metatable.__ipairs = metatable.__ipairs or require('inspect').ipairs
    metatable.__pairs  = metatable.__pairs  or require('inspect').pairs
    return ffi.metatype(name, metatable)
end

return exports
