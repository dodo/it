local ffi = require 'ffi'
local doc = require 'util.doc'
local cface = require 'cface'
local Prototype = require 'prototype'

local Pixel = Prototype:fork()

local refc
local function cdef(value_type, channel_type)
    local def
    local name = 'it_pixels' .. tostring(refc or '')
    refc = (refc or 0) + 1
    if ffi.abi 'le' then
        def = [[typedef struct _%s {
            union u { %s i; struct bgra {%s b,g,r,a;} c; } u;
        } %s;]]
    else -- big endian
        def = [[typedef struct _%s {
            union u { %s i; struct argb {%s a,r,g,b;} c; } u;
        } %s;]]
    end
    cface.declaration(string.format(def, name, value_type, channel_type, name))
    return name
end
cdef('uint32_t', 'uint8_t')
local default = ffi.new('it_pixels', {})

function Pixel:__new(pixels, width, value_type, channel_type)
    if value_type and channel_type then
        self.native = ffi.new(cdef(value_type, channel_type), {})
    else
        self.native = default
    end
    self.pixels = pixels
    self.width = width
end
doc.info(Pixel.__new,
        'Pixel:new',
        '( pixels, width, value_type="uint32_t", channel_type="uint8_t" )')

function Pixel:unpack(i)
    local p = self.native
    p.u.i = i
    return p.u.c.r, p.u.c.g, p.u.c.b, p.u.c.a
end
doc.info(Pixel.unpack, 'pixel:unpack', '( uint32_value )')

function Pixel:pack(r, g, b, a)
    local p = self.native
    p.u.c.r, p.u.c.g, p.u.c.b, p.u.c.a = r or 0, g or 0, b or 0, a or 0
    return p.u.i
end
doc.info(Pixel.pack, 'pixel:pack', '( r=0, g=0, b=0, a=0 )')

function Pixel:rawget(x, y)
    return self.pixels[x + y * self.width]
end
doc.info(Pixel.rawget, 'pixel:rawget', '( x, y )')

function Pixel:rawset(x,y, c)
    if self.pixels == nil then return end
    self.pixels[x + y * self.width] = c
end
doc.info(Pixel.rawset, 'pixel:rawset', '( x, y, c )')

function Pixel:get(x, y)
    if self.pixels == nil then return end
    return self:unpack(self:rawget(x, y))
end
doc.info(Pixel.get, 'pixel:get', '( x, y )')

function Pixel:set(x,y, r,g,b,a)
    self:rawset(x, y, self:pack(r,g,b,a))
end
doc.info(Pixel.set, 'pixel:set', '( x, y, r=0, g=0, b=0, a=0 )')

return Pixel
