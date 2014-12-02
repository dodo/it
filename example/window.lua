local util = require 'util'

local width = 352
local height = 240


process:on('exit', function (code)
    print(code, "going down …")
end)

process:on('panic', function (err)
    print("PANIC!")
end)


window = require('window'):new()


if process.argv[#process.argv]:match('.png$') then
    local cairo = require 'cairo'
    png = cairo.surface_from_png(process.argv[#process.argv])
    width, height = cairo.get_size(png)
    window.scope:define('png', png.object, function ()
        require('cairo')
        png = require('ffi').cast('cairo_surface_t*', _D.png)
    end)
end


window.scope:import(function ()
--     print("window" .. require('util').dump(window))
    local x = 0
    window:on('need render', function ()
--         window.native:blit(window.native:surface())
        window:surface(function (cairo)
            local cr = cairo.context
--             print("drawing stuff", require('util').dump(cairo))
            local w,h = window.width*0.5, window.height*0.5
            if png then
                cr:set_source_surface(png, 0, 0)
                cr:paint()
            else
                require('./samples').quads(cr, 0, 0, window.width, window.height)
                require('./samples').quads(cr, w/4,h/4, w,h)
            end
            require('./samples').arc(cr, w,h, x)
        end)
--         x = (x+0.1 - 1) % 100 + 1
        x = x % 100 + 1

    end)
    window:on('close', function ()
        print "window closed …"
        window:write_to_png('window.png')
        print "window content written to window.png …"
        process.exit()
    end)
end)


window:open("test", width, height)
print "window opened …"


require('./samples').test('arc', window.width, window.height,
    window.width*0.5, window.height*0.5, 100)
require('./samples').test('quads', window.width, window.height,
    0,0,window.width, window.height)
