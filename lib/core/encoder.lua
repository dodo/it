local ffi = require 'ffi'
local _ffi = require 'util._ffi'
local cface = require 'cface'
local Frame = require 'frame'
local Scope = require 'scope'
local Thread = require 'thread'
local _table = require 'util.table'
local Metatype = require 'metatype'

cface(_it.libdir .. "schrovideoformat.h")
cface(_it.libdir .. "schroencoder.h")
cface.typedef('struct _$', 'OGGZ')
cface.metatype('SchroEncoder')
cface.metatype('SchroEncoderFrame')
cface.metatype('SchroVideoFormat')


local Encoder = require(context and 'events' or 'prototype'):fork()
Encoder.type = Metatype:struct("it_encodes", {
    "it_threads *thread";
    "it_states *hooks[SCHRO_ENCODER_FRAME_STAGE_LAST]";
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
    hook = [[void it_hooks_stage_encoder(it_encodes* enc,
                                         SchroEncoderFrameStateEnum stage,
                                         it_states* ctx)]];
    push = [[int it_pushes_frame_encoder(it_encodes* enc, it_frames* fr)]];
})


function Encoder:init(filename, pointer)
    if self.prototype.init then self.prototype.init(self) end
    self.frame_format = 'ARGB'
    self.push = self:bind('push')
    if pointer then -- other stuff not needed in scope context
        self.native = self.type:ptr(pointer)
        self.raw = self.native.encoder
        self.thread = context.thread
        self.thread = (pointer == _D.encoder) and
                context.thread or Thread:new(self.native.thread)
        self.format = _table.readonly(self:getformat().raw)
        self.settings = _table.readonly(self.native:getsettings())
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
    self.stage = {} -- lazy filled when needed
    self.native = self.type:create(nil, self.thread.reference)
    self.raw = self.native.encoder
    self.settings = self.native:getsettings()
    self.scope:define('encoder', self.native, function ()
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
    self.native:setformat(format.pointer)
    self.native:start(self.output, self.settings)
    -- make format and settings readonly
    for key, value in pairs(self.settings) do
        self.settings[key] = _table.readonly(value)
    end
    self.settings = _table.readonly(self.settings)
    self.format = _table.readonly(self.format)
    for _, stage in pairs(self.stage) do
        local err = stage:run()
        if err then error(err) end
    end
    self.thread:start() -- at last
end

local STAGE_ENUM = {
    typ="SchroEncoderFrameStateEnum", prefix="SCHRO_ENCODER_FRAME_STAGE_"}
function Encoder:hook(stage)
    stage = _ffi.convert_enum('stage', stage, STAGE_ENUM.typ, STAGE_ENUM.prefix)
    local stage_name =_ffi.enum_string(stage, STAGE_ENUM.typ, STAGE_ENUM.prefix)
    local scope = Scope:new()
    self.stage[stage_name] = scope
    self.native:hook(stage, scope.state)
    scope:define('stage', stage_name)
    scope:define('encoder', self.native, function ()
        encoder = require('encoder'):new(nil, _D.encoder)
        encoder.stage = _D.stage
        -- expose SchroEncoderFrames
        encoder:on('run stage', function (pointer)
            local frame = require('ffi').cast('SchroEncoderFrame*', pointer)
            encoder:emit('stage', frame)
        end)
    end)
    return scope
end

function Encoder:push(frame)
    if self.native and frame and frame.render then
        frame.raw = nil -- C: fr->frame = NULL; // prevent schro_frame_unref
        return self.native:push(frame:render())
    end
    return 0
end

function Encoder:getformat()
    local pointer = self.native:getformat()
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
