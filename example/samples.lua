local util = require 'util'
local cairo = require 'cairo'

local samples = {}


function samples.arc(cr, xc, yc, radius)
    local angle1, angle2 = math.rad(45), math.rad(180)

    cr:set_source_rgb(0,0,0)
    cr:set_line_width(10)
    cr:arc(xc, yc, radius, angle1, angle2)
    cr:stroke()

    -- draw helping lines
    cr:set_source_rgba(1, 0.2, 0.2, 0.6)
    cr:set_line_width(6)

    cr:arc(xc, yc, 10, 0, math.rad(360))
    cr:fill()

    cr:arc(xc, yc, radius, angle1, angle1)
    cr:line_to(xc, yc)
    cr:arc(xc, yc, radius, angle2, angle2)
    cr:line_to(xc, yc)
    cr:stroke()
end

function samples.quads(cr, xc, yc, width, height)
    local w, h = width*0.5, height*0.5
    cr:set_source_rgb(1,0,0)
    cr:rectangle(xc,   yc,   w, h)
    cr:fill()
    cr:set_source_rgb(0,1,0)
    cr:rectangle(xc,   yc+h, w, h)
    cr:fill()
    cr:set_source_rgb(0,0,1)
    cr:rectangle(xc+w, yc,   w, h)
    cr:fill()
    cr:set_source_rgb(1,1,1)
    cr:rectangle(xc+w, yc+h, w, h)
    cr:fill()
end


function samples.test(name, width, height, ...)
    local surface = cairo.surface('ARGB32', width, height)
--     print("render test image", 'cairodemo-' .. name .. '.png', util.dump(surface))
    samples[name](surface.context, ...)
    surface.object:write_to_png('cairodemo-' .. name .. '.png')
end

return samples
