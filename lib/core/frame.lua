local ffi = require 'ffi'
local fs = require 'fs'

ffi.cdef(fs.read(_it.libdir .. "schroframe.h"))

local function frame(ref)
    return ffi.new("SchroFrame*", ref)
end

return frame