local ffi = require 'ffi'
local doc = require 'util.doc'

local pixel = {}

if ffi.abi 'le' then
    ffi.cdef [[typedef struct util_pixel {
        union u { uint32_t i; struct bgra {uint8_t b,g,r,a;} c; } u;
    } util_pixel;]]
else -- big endian
    ffi.cdef [[typedef struct util_pixel {
        union u { uint32_t i; struct argb {uint8_t a,r,g,b;} c; } u;
    } util_pixel;]]
end

function pixel.unpack(i)
    local p = ffi.new('util_pixel', {})
    p.u.i = i
    return p.u.c.r, p.u.c.g, p.u.c.b, p.u.c.a
end
doc.info(pixel.unpack, 'util_pixel.unpack', '( uint32_value )')

function pixel.pack(r, g, b, a)
    local p = ffi.new('util_pixel', {})
    p.u.c.r, p.u.c.g, p.u.c.b, p.u.c.a = r or 0, g or 0, b or 0, a or 0
    return p
end
doc.info(pixel.pack, 'util_pixel.pack', '( r=0, g=0, b=0, a=0 )')

function pixel.get(pixels, width, x, y)
    return pixel.unpack(pixels[x + y * width])
end
doc.info(pixel.get, 'util_pixel.get', '( pixels, width, x, y )')

function pixel.set(pixels, width, x,y, r,g,b,a)
    pixels[x + y * width] = pixel.pack(r,g,b,a).u.i
end
doc.info(pixel.set, 'util_pixel.set', '( pixels, width, x, y, r=0, g=0, b=0, a=0 )')

return pixel
