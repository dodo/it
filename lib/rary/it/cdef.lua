local doc = require 'util.doc'

local cdef = { loaded = {} }
local loadcdefdb = loadfile(_it.execpath .. 'vendor/cdefdb/cdef.lua')


function cdef.load(path)
    if cdef.loaded[path] then return cdef.loaded[path] end
    local cpath = package.cpath
    local cdefdb = loadcdefdb(path .. 'cdefdb.so')
    cdef.loaded[path] = cdefdb
    return cdefdb
end
doc.info(cdef.load, 'cdef.load', '( directory_path )')

if not process.verbose then
    cdef.call = cdef.load(_it.execpath)
else
    local _cdef = cdef.load(_it.execpath)
    function cdef.call(spec)
        -- dont print cdefs when booting it:
        spec.verbose = process.cdefs
        -- if you still want them, just change process.cdefs
        local success, C, ffi = pcall(_cdef, spec)
        if not success then
            local err = C
            print(err)
        else
            return C, ffi
        end
    end
end
doc.info(cdef.call, 'cdef.call', '( { '
    .. '[functions = { }], '
    .. '[variables = { }], '
    .. '[constants = { }], '
    .. '[structs = { }], '
    .. '[unions = { }], '
    .. '[enums = { }], '
    .. '[typedefs = { }], '
    .. '[verbose = false], '
    .. '[find = false], '
    .. ' } )')


return setmetatable(cdef, { __call = function (t, ...)
    return cdef.call(...)
end })
