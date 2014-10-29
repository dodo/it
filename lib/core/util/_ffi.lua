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

return exports
