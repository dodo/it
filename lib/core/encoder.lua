local ffi = require 'ffi'
local _ffi = require 'util._ffi'
local cface = require 'cface'
local Frame = require 'frame'
local Thread = require 'thread'
local _table = require 'util.table'
local Metatype = require 'metatype'

cface(_it.libdir .. "schrovideoformat.h")
cface.typedef('struct _$', 'SchroEncoder')
cface.typedef('struct _$', 'OGGZ')


local Encoder = require(thread and 'events' or 'prototype'):fork()
Encoder.type = Metatype:struct("it_encodes", {
    "it_threads *thread";
    "SchroEncoder *encoder";
    "OGGZ *container";
    "int64_t granulepos";
    "int64_t packetno";
    "bool eos_pulled";
    "bool started";
    "long serialno";
    "int frames";
    "int length";
    "unsigned char *buffer";
})


Encoder.type:api('Encoder', {'start', 'getsettings', 'getformat', 'setformat'})
Encoder.type:load(_it.libdir .. "/api.so", {
    init = [[void it_inits_encoder(it_encodes* enc, it_threads* thread)]];
    push = [[int it_pushes_frame_encoder(it_encodes* enc, it_frames* fr)]];
})


function Encoder:init(filename, pointer)
    if self.prototype.init then self.prototype.init(self) end
    self.frame_format = 'ARGB'
    self.push = self:bind('push')
    if pointer then -- other stuff not needed in scope context
        self._handle = self.type:ptr(pointer)
        self.thread = thread -- reuse context global
        self.format = _table.readonly(self:getformat().raw)
        self.settings = _table.readonly(self._handle:getsettings())
        self.start = nil
        return
    end
    self.thread = Thread:new()
    self.scope = self.thread.scope
    self.output = filename or process.stdnon
    self.format = { -- defaults
        width = 352,
        height = 240,
        clean_width = 352,
        clean_height = 240,
        left_offset = 0,
        top_offset = 0,
    }
    self._handle = self.type:create(nil, self.thread.reference)
    self.settings = self._handle:getsettings()
    self.scope:define('encoder', self._handle, function ()
        encoder = require('encoder'):new(nil, encoder)
        -- expose userdata as buffers
        encoder:on('userdata', function (raw, len)
            encoder:emit('data', require('buffer'):new(raw, len))
        end)
        -- expose SchroFrames as objects
        encoder:on('need frame', function ()
            local frame = require('frame'):new(
                encoder.format.width,
                encoder.format.height,
                encoder.frame_format
            )
            _ = encoder:emit('frame', frame) or encoder:push(frame)
        end)
    end)
end

local ENUMS = {
  index             = {typ="SchroVideoFormatEnum", prefix="VIDEO_FORMAT_"},
  chroma_format     = {typ="SchroChromaFormat",    prefix="CHROMA_"},
  colour_primaries  = {typ="SchroColourPrimaries", prefix="COLOUR_PRIMARY_"},
  colour_matrix     = {typ="SchroColourMatrix",    prefix="COLOUR_MATRIX_"},
  transfer_function = {typ="SchroTransferFunction",prefix="TRANSFER_CHAR_"},
}
function Encoder:start()
    local format = self:getformat()
    _ffi.update(format.raw, self.format, {prefix="SCHRO_", enums=ENUMS})
    self._handle:setformat(format.pointer)
    self._handle:start(self.output, self.settings)
    -- make format and settings readonly
    for key, value in pairs(self.settings) do
        self.settings[key] = _table.readonly(value)
    end
    self.settings = _table.readonly(self.settings)
    self.format = _table.readonly(self.format)
    self.thread:start() -- at last
end

function Encoder:push(frame)
    if self._handle and frame and frame.render then
        frame.raw = nil -- C: fr->frame = NULL; // prevent schro_frame_unref
        return self._handle:push(frame:render())
    end
    return 0
end

function Encoder:getformat()
    local pointer = self._handle:getformat()
    return {
        raw = ffi.cast('SchroVideoFormat*', pointer),
        pointer = pointer,
    }
end


function Encoder.debug(level)
    ffi.cdef [[void it_sets_schro_debug_level(int level);]]
    cface.register(_it.libdir .. "/api.so").it_sets_schro_debug_level(
        _table.index(
            {"ERROR","WARNING","INFO","DEBUG","LOG"},
            string.upper(level)
        ) or 0
    )
end

return Encoder
