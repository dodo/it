local ffi = require 'ffi'
local util = require 'util'
local cface = require 'cface'
local Metatype = require 'metatype'

local exports = {}
local cairo = exports

cface(_it.libdir .. "cairo.h")

exports.C = Metatype:fork():lib('cairo', 'cairo_'):new()
exports.ctype = {
    context = Metatype:use('cairo', 'cairo_','t'        , 'destroy'),
    surface = Metatype:use('cairo', 'cairo_surface_','t', 'destroy'),
}


function exports.surface(format, width, height)
    local result = {C = cairo.C}
    result.object = cairo.C.image_surface_create(
        'CAIRO_FORMAT_' .. format,
        width, height)
    result.context = cairo.ctype.context.create(result.object)
    return result
end

function exports.surface_from(data, format, width, height, stride)
    local result = {C = cairo.C}
    result.object = cairo.C.image_surface_create_for_data(
        data, 'CAIRO_FORMAT_' .. format,
        width, height, stride)
    result.context = cairo.ctype.context.create(result.object)
    return result
end

function exports.get_data(surface)
    -- do any pending drawing for the surface
    surface.object:flush()
    surface.object:mark_dirty()
    return ffi.cast('void*', cairo.C.image_surface_get_data(surface.object))
end

function exports.version()
    return "libcairo " .. ffi.string(cairo.C.version_string())
end

return exports
