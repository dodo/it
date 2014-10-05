local ffi = require 'ffi'
local util = require 'util'
local Scope = require 'scope'
local EventEmitter = require 'events'

require('cface')(_it.libdir .. "schrovideoformat.h")

local Encoder = EventEmitter:fork()

_it.loads('Encoder')
function Encoder:init()
    self.prototype.init(self)
    self.scope = Scope:new()
    self._handle = _it.encodes()
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
        local Buffer = require 'buffer'
        context:on('userdata', function (raw, len)
            context:emit('data', Buffer:new(raw, len))
        end)
        local frame = require 'frame'
        context:on('rawframe', function (raw)
            context:emit('frame', frame(raw))
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
    self._handle:start(self.output, self.settings)
    -- make format and settings readonly
    for key, value in pairs(self.settings) do
        self.settings[key] = util.readonlytable(value)
    end
    self.settings = util.readonlytable(self.settings)
    self.format = util.readonlytable(self.format)
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
