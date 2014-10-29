local fs = require 'fs'
local ffi = require 'ffi'
local util = require 'util'

local exports = {}
local cface = exports

local function escape(match)
    return match:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1");
end

_CFACE_REGISTRY = {}
function exports.register(clib)
    if type(clib) == 'string' then
        local name = clib
        clib = _CFACE_REGISTRY[name] or ffi.load(name)
        _CFACE_REGISTRY[name] = clib
    end
    return clib
end

function exports.interface(filename)
    local header = fs.read(filename)
    -- at least support simple `#define key value` usage
    local define = {}
    -- remove all defines and store their key,value pairs
    local key, value
    for src in header:gmatch('(/?/?%s*#%s*define[^\n]-\n)') do
        if not src:match('^//') then
            header = header:gsub(escape(src:gsub('^[^#]*', "")), "")
            key, value = src:match('define%s+(%g+)%s*([^\n]*)\n')
            if key then
                -- replace defines within define
                for k,v in pairs(define) do
                    value = value:gsub(k, v)
                end
                define[escape(key)] = value
            end
        end
    end
    -- replace used defines
    for key,value in pairs(define) do
        header = header:gsub(key, value)
    end
    -- now use that …
    cface.declaration(header)
    return true
end

_CFACE_ERROR_SIZE = 10
function exports.declaration(cdecl, ...)
    util.xpcall(ffi.cdef, function (err)
        if err:match('at line %d+$') then
            cdecl = cdecl .. "\n"
            local ln = tonumber(err:match('at line (%d+)$'))
            local i = 1
            local lines = {}
            for line in cdecl:gmatch('([^\n]*)\n') do
                lines[((i - 1) % _CFACE_ERROR_SIZE) + 1] = line
                if i == ln then
                    err = err .. "\n"
                    for n = 1, _CFACE_ERROR_SIZE do
                        line = lines[((i + n - 1 - _CFACE_ERROR_SIZE) % _CFACE_ERROR_SIZE) + 1]
                        if line then
                            err = err .. "        " .. line .. "\n"
                        end
                    end
                    if line then
                        err = err .. "        " .. string.rep('~', #line)
                    end
                    break
                end
                i = i + 1
            end
        end
        return err
    end, cdecl, ...)
end
exports.decl = exports.declaration -- alias

function exports.typedef(ct, name)
    if ct:find('%$') then
        ct = ct:gsub('%$', name)
    end
    cface.declaration(string.format("typedef %s %s;", ct, name))
    return ct
end

function exports.struct(name, fields)
    local header = ""
    for _, field in pairs(fields) do
        header = header .. field .. ";"
    end
    cface.typedef(string.format("struct _%s {%s}", name, header), name)
end

function exports.struct_from(name, filename)
    -- TODO load only on struct from filename (maybe recursive?)
end

exports.int = ffi.typeof(ffi.new('int'))

function exports.optint(number)
    if number then
        return cface.int(number)
    end
end

function exports.assert(NIL)
    if NIL == nil then
        assert(not NIL) -- NULL pointer
    end
    return NIL
end

cface.struct("it_strings", {
    "const char *data";
    "int *length";
})
function exports.string(cstring)
    return ffi.string(cstring.data, cstring.length)
end


return setmetatable(cface, { __call = function (mt,...)
    return exports.interface(...)
end })
