local ffi = require 'ffi'
local Prototype = require 'prototype'

require('cface')(_it.libdir .. "schroframe.h")


local Frame = Prototype:fork()

_it.loads('Frame')
function Frame:init(width, height, format, pointer)
    self.format = format or 'ARGB'
    self.width, self.height = width, height
    self._handle = _it.frames(width, height)
    self:create(pointer)
end

function Frame:create(pointer)
    self._pointer = self._handle:create(pointer or
        util.convert_enum('format', self.format,
        "SchroFrameFormat", "SCHRO_FRAME_FORMAT_"))
    self.raw = ffi.new("SchroFrame*", self._pointer)
    return self.raw
end

return Frame
