local ffi = require 'ffi'
local cdef = require 'cdef'
local _ffi = require 'util._ffi'
local Prototype = require 'prototype'
local Metatype = require 'metatype'
local doc = require 'util.doc'
-- local lgi = require 'lgi' -- lazy ↓

cdef({
    typedefs = 'SchroFrame*',
    verbose  = process.verbose,
})


local Frame = Prototype:fork()
Frame.type = Metatype:struct("it_frames", cdef)

Frame.type:load('libencoder.so', {
    ref = 'it_refs',
    unref = 'it_unrefs',
    init = 'it_inits_frame',
    create = 'it_creates_frame',
    convert = 'it_converts_frame',
    reference = 'it_refs_frame',
    reverse_order = 'it_reverses_order_frame',
    __gc = 'it_frees_frame',
}, cdef)


function Frame:__new(width, height, format, pointer)
    self.format = format or 'ARGB'
    self.native = self.type:create(nil, width, height)
    self.width, self.height = width, height
    self:create(pointer)
end
doc.info(Frame.__new,
        'Frame:new',
        '( width, height, format="ARGB"[, pointer] )')

function Frame:__cast(pointer)
    -- TODO format missing
    self.native = self.type:ptr(pointer)
    self.height = tonumber(self.native.height)
    self.width = tonumber(self.native.width)
end
doc.todo(Frame.__cast, 'Frame:cast', '( pointer )')

function Frame:create(pointer)
    if pointer then
        self.native:reference(pointer)
    else
        self.native:create(_ffi.convert_enum('format', self.format,
            "SchroFrameFormat", "SCHRO_FRAME_FORMAT_"))
    end
    self.raw = self.native.frame
    return self.raw
end
doc.info(Frame.create, 'frame:create', '( [pointer] )')

function Frame:new_convert(format) -- format or frame
    if not format then return self end
    if Frame:isinstance(format) then
        format = format.format
    end
    local frame = Frame:new(self.width, self.height, format)
    self.native:convert(frame.native)
    frame:create(frame.native.frame)
    return frame
end
doc.info(Frame.new_convert, 'frame:new_convert', '( format|frame )')

function Frame:convert(format) -- format or frame
    if format and Frame:isinstance(format) then
        local frame = format
        self.native:convert(frame.native)
        frame:create(frame.native.frame)
        return frame
    elseif format then
        local frame = self:new_convert(format)
        self.native.frame = frame.raw
        self.raw = self.native.frame
        frame.native = nil
        frame.raw = nil
        return self
    else
        return self
    end
end
doc.info(Frame.convert, 'frame:convert', '( format|frame )')

function Frame:data()
    local data = {}
    for i = 0,2 do
        if self.raw.components[i].length > 0 then
            table.insert(data, self.raw.components[i].data)
        end
    end
    return unpack(data)
end
doc.info(Frame.data, 'frame:data', '(  )')

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
doc.info(Frame.buffer, 'frame:buffer', '(  )')


function Frame:surface()
    self.rendered = false
    if self._surface then return self._surface end
--     self:validate()
    self._surface = require('lib.cairo').surface_from(
        self.raw.components[0].data, 'ARGB32',
        self.width, self.height,
        self.raw.components[0].stride)
    return self._surface
end
doc.info(Frame.surface, 'frame:surface', '(  )')

function Frame:fix_endian()
    --- from cairo docs:
    -- CAIRO_FORMAT_ARGB32 […] The 32-bit quantities are stored native-endian […]
    if ffi.abi 'le' then
        self.native:reverse_order()
    end
end
doc.info(Frame.fix_endian, 'frame:fix_endian', '(  )')

function Frame:render()
    if self.rendered then return self.native end
    self.rendered = true
    if self._surface then
        -- do any pending drawing for the surface
        self._surface.object:flush()
        self._surface.object:mark_dirty()
        -- revert cairo mess
        self:fix_endian()
    end
    return self.native
end
doc.info(Frame.render, 'frame:render', '(  )')

function Frame:write_to_png(filename)
    -- init cairo
    self:surface()
    -- convert frame data into cairo mess
    self:fix_endian()
    -- io
    return self._surface.object:write_to_png(filename)
end
doc.info(Frame.write_to_png, 'frame:write_to_png', '( filename )')

function Frame:validate()
    local cairo = require 'lib.cairo'
    local surface_stride = cairo.C.format_stride_for_width('ARGB32', self.width)
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
doc.info(Frame.validate, 'frame:validate', '(  )')

return Frame
