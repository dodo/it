 local ffi = require 'ffi'
local util = require 'util'
local cface = require 'cface'
local Metatype = require 'metatype'
local doc = require 'util.doc'

local exports = {}
local pixman = exports

cface(_it.libdir .. "pixman.h")

exports.LIB = 'pixman-1'
exports.C = Metatype:fork():lib(pixman.LIB, 'pixman_'):new()
exports.ctype = {
    image = Metatype:use(pixman.LIB, 'pixman_image_','t', 'unref'),
}


function exports.image(format, width, height, stride, data)
    return pixman.ctype.image.create_bits_no_clear(
        'PIXMAN_' .. format, width, height, data, stride)
end
doc.info(exports.surface, 'pixman.image', '( format, width, height, stride, data=nil )')

function exports.clear_image(format, width, height, stride, data)
    return pixman.ctype.image.create_bits(
        'PIXMAN_' .. format, width, height, data, stride)
end
doc.info(exports.surface, 'pixman.clear_image', '( format, width, height, stride, data=nil )')

function exports.get_data(image, type)
    type = type or 'void*'
    return ffi.cast(type, pixman.C.image_get_data(image))
end
doc.info(exports.get_data, 'pixman.get_data', '( surface, type="void*" )')

function exports.get_size(image)
    return pixman.C.image_get_width(image),
           pixman.C.image_get_height(image)
end
doc.info(exports.get_size, 'cairo.get_size', '( surface )')

function exports.version()
    return "libpixman " .. ffi.string(pixman.C.version_string())
end
doc.info(exports.version, 'pixman.version', '(  )')

return exports
