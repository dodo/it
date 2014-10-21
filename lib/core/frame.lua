local ffi = require 'ffi'
local util = require 'util'
local Prototype = require 'prototype'
-- local lgi = require 'lgi' -- lazy ↓

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

function Frame:convert(format) -- format or frame
    if format and Frame:isinstance(format) then
        local frame = format
        frame:create(self._handle:convert(frame._pointer))
        return frame
    elseif format then
        local pointer = self._handle:convert(
            util.convert_enum('format', format,
                "SchroFrameFormat", "SCHRO_FRAME_FORMAT_"
            )
        )
        return Frame:new(self.width, self.height, format, pointer)
    else
        return self
    end
end

function Frame:buffer()
    local buffers = {}
    for i = 0,2 do
        if self.raw.components[i].length > 0 then
            table.insert(buffers, require('buffer'):new(
                self.raw.components[i].data,
                self.raw.components[i].length,
                'frame' -- encoding
            ))
        end
    end
    return unpack(buffers)
end

function Frame:surface()
    if self._surface then return self._surface end
    local cairo = require('lgi').cairo -- lazy load lgi
    local f = 'ARGB'--self.format
--     self:validate()
    local surface = cairo.ImageSurface.create_for_data(
        self._handle:getdata(), f,
        self.width, self.height,
        cairo.Format.stride_for_width(f, self.width)
    )
    self._surface = {
        object = surface,
        context = cairo.Context.create(surface),
    }
    return self._surface
end

function Frame:fix_endian()
    --- from cairo docs:
    -- CAIRO_FORMAT_ARGB32 […] The 32-bit quantities are stored native-endian […]
    if not _it.is_big_endian then
        self._handle:reverse_order()
    end
end

function Frame:render()
    if self._surface then
        -- do any pending drawing for the surface
        self._surface.object:flush()
        self._surface.object:mark_dirty()
        -- revert cairo mess
        self:fix_endian()
    end
    return self._handle
end

function Frame:write_to_png(filename)
    -- init cairo
    self:surface()
    -- convert frame data into cairo mess
    self:fix_endian()
    -- io
    return self._surface.object:write_to_png(filename)
end

function Frame:validate()
    local cairo = require('lgi').cairo -- lazy load lgi
    local surface_stride = cairo.Format.stride_for_width(self.format, self.width)
    local frame_stride = self.raw.components[0].stride +
                         self.raw.components[1].stride +
                         self.raw.components[2].stride
    if surface_stride > frame_stride then
        return error(string.format(
            "prevented segfault: strides mismatch (surface wants %d but frame has %d)",
            surface_stride, frame_stride
        ))
    end
    return true
end

return Frame
