local ffi = require 'ffi'
local fs = require 'fs'


local function escape(match)
    return match:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1");
end

local function cface(filename)
    local header = fs.read(filename)
    -- at least support simple `#define key value` usage
    local define = {}
    -- remove all defines and store their key,value pairs
    for src,key,value in header:gmatch('(#define%s+(%g+)%s+([^\n]*)\n)') do
        header = header:gsub(escape(src), "")
        define[key] = value
    end
    -- replace used defines
    for key,value in pairs(define) do
        header = header:gsub(escape(key), value)
    end
    -- no use that …
    ffi.cdef(header)
    return true
end


return cface
