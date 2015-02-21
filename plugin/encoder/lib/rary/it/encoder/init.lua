local ffi = require 'ffi'
local _ffi = require 'util._ffi'
local util = require 'util'
local cdef = require 'cdef'
local cface = require 'cface'
local Scope = require 'scope'
local Thread = require 'thread'
local _table = require 'util.table'
local Metatype = require 'metatype'
local doc = require 'util.doc'
local debug_level
local Frame = require 'encoder.frame'

cdef({
    typedefs = 'SchroEncoder*',
    verbose  = process.verbose,
})
cface.metatype('SchroEncoder')
cface.metatype('SchroEncoderFrame')
cface.metatype('SchroVideoFormat')

local submodules = util.lazysubmodules('encoder', {'frame'})

local Encoder = require(process.context and 'events' or 'prototype'):fork(submodules)
Encoder.type = Metatype:struct("it_encodes", cdef)


Encoder.type:api('Encoder',
    {'start', 'debug', 'getsettings', 'getformat', 'setformat'},
    _it.plugin.encoder.apifile)
Encoder.type:load('libencoder.so', {
    init = 'it_inits_encoder',
    hook = 'it_hooks_stage_encoder',
    push = 'it_pushes_frame_encoder',
}, cdef)


local SCHRO = {prefix="SCHRO_", enums={
  index             = {typ="SchroVideoFormatEnum", prefix="VIDEO_FORMAT_"},
  chroma_format     = {typ="SchroChromaFormat",    prefix="CHROMA_"},
  colour_primaries  = {typ="SchroColourPrimaries", prefix="COLOUR_PRIMARY_"},
  colour_matrix     = {typ="SchroColourMatrix",    prefix="COLOUR_MATRIX_"},
  transfer_function = {typ="SchroTransferFunction",prefix="TRANSFER_CHAR_"},
}}
function Encoder:__new(filename, opts)
    self:init()
    opts = opts or {}
    self.thread = Thread:new()
    self.scope = self.thread.scope
    self.output = filename or process.stdnon
    if not opts.format then
        self.format = { -- defaults
            width = opts.width or 352,
            height = opts.height or 240,
            clean_width = opts.width or 352,
            clean_height = opts.height or 240,
            left_offset = 0,
            top_offset = 0,
        }
    end
    self.stage = {} -- lazy filled when needed
    self.native = self.type:create(nil, self.thread.reference,
        -- schroEncoder will autoguess later a better std video format
        _ffi.convert_enum('format', opts.format or 'custom',
            SCHRO.enums.index.typ, SCHRO.prefix .. SCHRO.enums.index.prefix)
    )
    if opts.format then
        self.format = _table.slowcopy(_ffi.update(self:getformat().raw, {}, SCHRO))
    end
    self.raw = self.native.encoder
    self.settings = self.native:getsettings()
    self.scope:define('_it_encodes_', self.native, function ()
        encoder = require('encoder'):cast(_D._it_encodes_, process.context.thread)
        -- expose userdata as buffers
        encoder:on('userdata', function (raw, len)
            encoder:emit('data', require('buffer'):new(raw, len))
        end)
        -- expose SchroFrames as objects
        encoder:on('need frame', function ()
            local frame = require('encoder.frame'):new(
                encoder.format.width,
                encoder.format.height,
                encoder.frame_format
            )
            _ = encoder:emit('frame', frame) or encoder:push(frame)
        end)
    end)
end
doc.info(Encoder.__new, 'Encoder:new', '( filename=process.stdout, opts={} )')

function Encoder:__cast(pointer, thread)
    self:init()
    self.native = self.type:ptr(pointer)
    self.raw = self.native.encoder
    self.thread = thread or Thread:new(self.native.thread)
    self.format = _table.readonly(self:getformat().raw)
    self.settings = _table.readonly(self.native:getsettings())
    self.start = nil
end
doc.info(Encoder.__cast, 'Encoder:cast', '( pointer[, thread] )')

function Encoder:init()
    if self.prototype.__new then self.prototype.__new(self) end
    self.frame_format = 'ARGB'
    self.push = self:bind('push')
end
doc.private(Encoder.init, 'encoder:init', '(  )')

function Encoder:start()
    -- turn on errors at least
    if not debug_level then Encoder.debug('error') end
    local format = self:getformat()
    local _, changed = _ffi.update(format.raw, self.format, SCHRO)
    if changed then
        self.native:setformat(format.pointer)
    end
    self.native:start(self.output, self.settings)
    -- make format and settings readonly
    for key, value in pairs(self.settings) do
        self.settings[key] = _table.readonly(value)
    end
    self.settings = _table.readonly(self.settings)
    self.format = _table.readonly(self.format)
    for _, stage in pairs(self.stage) do
        stage:run()
    end
    self.thread:start() -- at last
end
doc.info(Encoder.start, 'encoder:start', '(  )')

local STAGE_ENUM = {
    typ="SchroEncoderFrameStateEnum", prefix="SCHRO_ENCODER_FRAME_STAGE_"}
function Encoder:hook(stage)
    stage = _ffi.convert_enum('stage', stage, STAGE_ENUM.typ, STAGE_ENUM.prefix)
    local stage_name =_ffi.enum_string(stage, STAGE_ENUM.typ, STAGE_ENUM.prefix)
    local scope = Scope:new()
    self.stage[stage_name] = scope
    self.native:hook(stage, scope.state)
    scope:define('stage', stage_name)
    scope:define('encoder', self.native) -- could have different thread than this scope
    scope:import(function ()
        encoder = require('encoder'):cast(_D.encoder)
        encoder.stage = _D.stage
        -- expose SchroEncoderFrames
        encoder:on('run stage', function (pointer)
            local frame = require('ffi').cast('SchroEncoderFrame*', pointer)
            encoder:emit('stage', frame)
        end)
    end)
    return scope
end
doc.info(Encoder.hook, 'encoder:hook', '( stage )')

function Encoder:push(frame)
    if self.native and frame and frame.render then
        frame.raw = nil -- C: fr->frame = NULL; // prevent schro_frame_unref
        return self.native:push(frame:render())
    end
    return 0
end
doc.info(Encoder.push, 'encoder:push', '( frame )')

function Encoder:getformat()
    local pointer = self.native:getformat()
    return {
        raw = ffi.cast('SchroVideoFormat*', pointer),
        pointer = pointer,
    }
end
doc.info(Encoder.getformat, 'encoder:getformat', '(  )')


function Encoder.debug(level)
    debug_level = _table.index(
        {"ERROR","WARNING","INFO","DEBUG","LOG"},
        string.upper(level)
    ) or 0
    debug.getregistry().Encoder.__index.debug(debug_level)
end
doc.info(Encoder.debug, 'Encoder.debug', '( level=0 )')

return Encoder
