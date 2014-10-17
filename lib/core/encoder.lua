local ffi = require 'ffi'
local util = require 'util'
local Scope = require 'scope'
local EventEmitter = require 'events'

require('cface')(_it.libdir .. "schrovideoformat.h")


local Encoder = EventEmitter:fork()

_it.loads('Encoder')
function Encoder:init(filename, pointer)
    self.prototype.init(self)
    self._pointer = pointer
    self.push = self:bind('push')
    self._handle = _it.encodes(pointer)
    if pointer then -- other stuff not needed in scope context
        self.start = nil
        self.format = util.readonlytable(self:getformat().raw)
        return
    end
    if filename == false then
        return
    end
    self.scope = Scope:new()
    self.output = filename or process.stdnon
    self.format = { -- defaults
        width = 352,
        height = 240,
        clean_width = 352,
        clean_height = 240,
        left_offset = 0,
        top_offset = 0,
    }
    self.settings = {}
    self._handle:create(self.scope.state, self.settings) -- FIXME maybe doing this lazy?
    -- process 'userdata' events to 'data' events
    self.scope:import(function ()
        -- encoder handle gets injected right before
        encoder = require('encoder'):new(nil, encoder)
        -- expose userdata as buffers
        local Buffer = require 'buffer'
        context:on('userdata', function (raw, len)
            context:emit('data', Buffer:new(raw, len))
        end)
        -- expose SchroFrames as objects
        local Frame = require 'frame'
        context:on('need frame', function ()
            local frame = Frame:new(
                encoder.format.width,
                encoder.format.height
            )
            _ = context:emit('frame', frame) or encoder:push(frame)
        end)
    end)
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
    local format = self:getformat()
    for key,value in pairs(self.format) do
        if ENUMS[key] then
            value = string.upper(tostring(value):gsub("%s", "_"))
            value = ffi.new(ENUMS[key].typ, ENUMS[key].prefix .. value)
        end
        format.raw[key] = value
    end
    self._handle:setformat(format.pointer)
    self._handle:start(self.output, self.settings)
    -- make format and settings readonly
    for key, value in pairs(self.settings) do
        self.settings[key] = util.readonlytable(value)
    end
    self.settings = util.readonlytable(self.settings)
    self.format = util.readonlytable(self.format)
end

function Encoder:push(frame)
    if self._handle and frame and frame._handle then
        return self._handle.push(
            self._pointer or self._handle,
            frame._handle
        )
    end
    return false
end

function Encoder:getformat()
    local pointer = self._handle.getformat(self._pointer or self._handle)
    return {
        raw = ffi.new("SchroVideoFormat*", pointer),
        pointer = pointer,
    }
end


function Encoder:debug(level)
    self._handle.setdebug(
        util.table_index(
            {"ERROR","WARNING","INFO","DEBUG","LOG"},
            string.upper(level)
        )
    )
end

return Encoder
