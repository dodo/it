local ffi = require 'ffi'

require('cface')(_it.libdir .. "schroframe.h")


local function frame(ref)
    return ffi.new("SchroFrame*", ref)
end


return frame
