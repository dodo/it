local ffi = require 'ffi'
local util = require 'util'
local cface = require 'cface'
local Metatype = require 'metatype'
local doc = require 'util.doc'

local exports = {}
local cairo = exports

cface(_it.libdir .. "cairo.h")

exports.LIB = 'cairo'
exports.C = Metatype:fork():lib(cairo.LIB, 'cairo_'):new()
exports.ctype = {
    context = Metatype:use(cairo.LIB, 'cairo_','t'        , 'destroy'),
    surface = Metatype:use(cairo.LIB, 'cairo_surface_','t', 'destroy'),
}


function exports.surface(format, width, height)
    local result = {C = cairo.C}
    result.object = cairo.C.image_surface_create(
        'CAIRO_FORMAT_' .. format,
        width, height)
    result.context = cairo.ctype.context.create(result.object)
    return result
end
doc.info(exports.surface, 'cairo.surface', '( format, width, height )')

function exports.surface_from(data, format, width, height, stride)
    local result = {C = cairo.C}
    result.object = cairo.C.image_surface_create_for_data(
        data, 'CAIRO_FORMAT_' .. format,
        width, height, stride)
    result.context = cairo.ctype.context.create(result.object)
    return result
end
doc.info(exports.surface_from,
        'cairo.surface_from',
        '( data, format, width, height, stride )')

function exports.surface_from_png(filename)
    local result = {C = cairo.C}
    result.object = cairo.C.image_surface_create_from_png(filename)
    result.context = cairo.ctype.context.create(result.object)
    return result
end
doc.info(exports.surface_from_png, 'cairo.surface_from_png', '( filename )')

function exports.get_data(surface, type)
    type = type or 'void*'
    -- do any pending drawing for the surface
    surface.object:flush()
    surface.object:mark_dirty()
    return ffi.cast(type, cairo.C.image_surface_get_data(surface.object))
end
doc.info(exports.get_data, 'cairo.get_data', '( surface, type="void*" )')

function exports.get_size(surface)
    return cairo.C.image_surface_get_width(surface.object),
           cairo.C.image_surface_get_height(surface.object)
end
doc.info(exports.get_size, 'cairo.get_size', '( surface )')

function exports.version()
    return "libcairo " .. ffi.string(cairo.C.version_string())
end
doc.info(exports.version, 'cairo.version', '(  )')

return exports
