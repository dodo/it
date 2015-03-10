local fs = require 'fs'
local ffi = require 'ffi'
local util = require 'util'
local doc = require 'util.doc'

local cface = {metatype = require('util._ffi').metatype}

local function escape(match)
    return match:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1");
end

_CFACE_REGISTRY = {}
function cface.register(clib, apifile)
    if type(clib) == 'string' then
        local name = clib
        if apifile then
            clib = _it.loads(name, apifile)
        else
            clib = _CFACE_REGISTRY[name]
            clib = clib or ffi.load(name)
            _CFACE_REGISTRY[name] = clib
        end
    end
    return clib
end
doc.info(cface.register, 'cface.register', '( clib[, apifile] )')

function cface.interface(filename)
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
        header = header:gsub('(' .. key .. ')([^%w_])', value .. '%2')
    end
    -- now use that …
    cface.declaration(header)
    return true, header, define
end
doc.info(cface.interface, 'cface.interface', '( filename )')

_CFACE_ERROR_SIZE = 10
function cface.declaration(cdecl, ...)
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
cface.decl = cface.declaration -- alias
doc.info(cface.decl, 'cface.declaration', '( cdecl[, ...] )')

function cface.typedef(ct, name)
    if ct:find('%$') then
        ct = ct:gsub('%$', name)
    end
    cface.declaration(string.format("typedef %s %s;", ct, name))
    return ct
end
doc.info(cface.typedef, 'cface.typedef', '( ct[, name] )')

function cface.struct(name, fields)
    local header = ""
    if fields then
        for _, field in pairs(fields) do
            header = header .. field .. ";"
        end
        header = "{" .. header .. "}"
    end
    cface.typedef(string.format("struct _%s %s", name, header), name)
end
doc.info(cface.struct, 'cface.struct', '( name[, fields] )')

function cface.struct_from(name, filename)
    -- TODO load only on struct from filename (maybe recursive?)
end
doc.todo(cface.struct_from, 'cface.struct_from', '( name, filename )')

 -- TODO move following code into util._ffi :

cface.int = ffi.typeof(ffi.new('int'))

function cface.optint(number)
    if number then
        return cface.int(number)
    end
end
doc.info(cface.optint, 'cface.optint', '( [number] )')

function cface.assert(NIL, msg)
    if NIL == nil then
        assert(not NIL, msg) -- NULL pointer
    end
    return NIL
end
doc.info(cface.assert, 'cface.assert', '( [NIL[, msg]] )')

cface.struct("it_strings", {
    "const char *data";
    "int length";
})

function cface.constchar(lstring, len)
    return ffi.new('it_strings', {lstring, len or string.len(lstring)})
end
doc.info(cface.constchar, 'cface.constchar', '( luastring[, length] )')

function cface.string(cstring)
    return ffi.string(cstring.data, cstring.length)
end
doc.info(cface.string, 'cface.string', '( cstring )')


return setmetatable(cface, { __call = function (mt,...)
    return cface.interface(...)
end })
