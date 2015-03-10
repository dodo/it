local ffi = require 'ffi'
local cdef = require 'cdef'
local _string = require 'util.string'
local doc = require 'util.doc'


local path = {}


-- interestingly basename is a macro pointing to a specific __*_basename c function
local C_basename do
    local name = _string.trim(cdef({find=true, macros='basename'})().extent)
    cdef({ functions = name })
    C_basename = ffi.C[name]
end

function path.basename(path)
    return ffi.string(C_basename(ffi.cast('char*', path)))
end
doc.info(path.basename, 'util_path.basename', '( path )')

cdef({ functions = 'dirname' })
function path.dirname(path)
    return ffi.string(ffi.C.dirname(ffi.cast('char*', path)))
end
doc.info(path.dirname, 'util_path.dirname', '( path )')


return path
