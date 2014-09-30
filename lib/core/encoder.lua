local io = require 'io'
local fs = require 'fs'
local ffi = require 'ffi'
local Scope = require 'scope'
local EventEmitter = require 'events'

ffi.cdef(fs.read(_it.libdir .. "schrovideoformat.h"))

local Encoder = EventEmitter:fork()

_it.loads('Encoder')
function Encoder:init()
    self.prototype.init(self)
    self.scope = Scope:new()
    self._handle = _it.encodes()
    self._handle:create(self.scope.state) -- FIXME maybe doing this lazy?
    self.format = {
        width = 320,
        height = 240,
        clean_width = 320,
        clean_height = 240,
        left_offset = 0,
        top_offset = 0,
    }
end

local ENUMS = {
  index             = {typ="SchroVideoFormatEnum", prefix="SCHRO_VIDEO_FORMAT_"},
  chroma_format     = {typ="SchroChromaFormat",    prefix="SCHRO_CHROMA_"},
  colour_primaries  = {typ="SchroColourPrimaries", prefix="SCHRO_COLOUR_PRIMARY_"},
  colour_matrix     = {typ="SchroColourMatrix",    prefix="SCHRO_COLOUR_MATRIX_"},
  transfer_function = {typ="SchroTransferFunction",prefix="SCHRO_TRANSFER_CHAR_"},
}
function Encoder:start()
    process.shutdown = false -- prevent process from shutting down
    local schroformat = self._handle:getformat()
    local ffiformat = ffi.new("SchroVideoFormat*", schroformat)
    for key,value in pairs(self.format) do
        if ENUMS[key] then
            value = string.upper(tostring(value):gsub("%s", "_"))
            value = ffi.new(ENUMS[key].typ, ENUMS[key].prefix .. value)
        end
        ffiformat[key] = value
    end
    self._handle:setformat(schroformat)
    self._handle:start()
end

return Encoder
