local ffi = require 'ffi'
local doc = require 'util.doc'

local pixel = {}

if ffi.abi 'le' then
    ffi.cdef [[typedef struct _it_pixels {
        union u { uint32_t i; struct bgra {uint8_t b,g,r,a;} c; } u;
    } it_pixels;]]
else -- big endian
    ffi.cdef [[typedef struct _it_pixels {
        union u { uint32_t i; struct argb {uint8_t a,r,g,b;} c; } u;
    } it_pixels;]]
end

local p = ffi.new('it_pixels', {})

function pixel.unpack(i)
    p.u.i = i
    return p.u.c.r, p.u.c.g, p.u.c.b, p.u.c.a
end
doc.info(pixel.unpack, 'util_pixel.unpack', '( uint32_value )')

function pixel.pack(r, g, b, a)
    p.u.c.r, p.u.c.g, p.u.c.b, p.u.c.a = r or 0, g or 0, b or 0, a or 0
    return p.u.i
end
doc.info(pixel.pack, 'util_pixel.pack', '( r=0, g=0, b=0, a=0 )')

function pixel.rawget(pixels, width, x, y)
    return pixels[x + y * width]
end
doc.info(pixel.rawget, 'util_pixel.rawget', '( pixels, width, x, y )')

function pixel.rawset(pixels, width, x,y, c)
    if pixels == nil then return end
    pixels[x + y * width] = c
end
doc.info(pixel.rawset, 'util_pixel.rawset', '( pixels, width, x, y, c )')

function pixel.get(pixels, width, x, y)
    if pixels == nil then return end
    return pixel.unpack(pixel.rawget(pixels, width, x, y))
end
doc.info(pixel.get, 'util_pixel.get', '( pixels, width, x, y )')

function pixel.set(pixels, width, x,y, r,g,b,a)
    pixel.rawset(pixels, width, x, y, pixel.pack(r,g,b,a))
end
doc.info(pixel.set, 'util_pixel.set', '( pixels, width, x, y, r=0, g=0, b=0, a=0 )')

return pixel
