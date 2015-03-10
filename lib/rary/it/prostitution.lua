-- emulated love
local fs = require 'fs'
local Window = require 'window'
local fake = require('util.table').fake
local dirname = require('util.path').dirname

--------------------------------------------------------------------------------
local function emulator(external_window)
window = external_window or window

local fs = require 'fs'
local ffi = require 'ffi'
local Pixel = require 'util.pixel'
local libcairo = require 'lib.cairo'
local touserdata = require('util._ffi').touserdata
local contains = require('util.table').index
local fake = require('util.table').fake
local fps = require('util.fps'):new()

--- global
-- love is fake object, that allows all keys to be indexed (recursive) and called
love = fake 'love'
love.fake = true -- for convenience
---
local love_context = {
    cr = nil,
    mouse = {0, 0},
    fgcolor = {1, 1, 1},
    bgcolor = {0, 0, 0},
}


function love.getVersion()
    return 0, 9, 2, "Prostitution"
end

-- love objects {{{
    -- ImageData {{{
local ImageData = fake 'ImageData'
ImageData.__index = ImageData

function ImageData.new(width, height)
    local data
    if type(width) == 'string' then
        local filename, width, height = width, nil, nil
        data = libcairo.surface_from_png(filename)
    elseif type(width) == 'number' and type(height) == 'number' then
        data = libcairo.surface('ARGB32', width, height)
    else
        return nil
    end
    data.width, data.height = libcairo.get_size(data)
    data.pixels = libcairo.get_data(data, 'uint32_t*')
    data.pixel = Pixel:new(data.pixels, data.width)
    local instance = touserdata(data.object)
    debug.setmetatable(instance, {
        __index = setmetatable(data, ImageData)
    })
    return instance
end

function ImageData:mapPixel(pixelFunction)
    local pixel = self.pixel
    local w, h = self.width, self.height
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            pixel:set(x, y, pixelFunction(x, y, pixel:get(x, y)))
        end
    end
end

function ImageData:setPixel(x, y, r, g, b, a)
    self.pixel:set(x, y, r, g, b, a)
end

function ImageData:getPixel(x, y)
    return self.pixel:get(x, y)
end

function ImageData:encode(filename)
    filename = tostring(filename)
    if not filename:match('.png$') then
        filename = filename .. '.png'
    end
    self.object:write_to_png(filename)
end

function ImageData:getPointer()
    return self.pointer -- stored in luaI_userdata
end

function ImageData:getSize()
    return self.width * 4 * self.height -- stride * height
end

function ImageData:getWidth()
    return self.width
end

function ImageData:getHeight()
    return self.height
end

function ImageData:getDimensions()
    return self.width, self.height
end

function ImageData:type()
    return "ImageData"
end

function ImageData:typeOf(name)
    return not not contains({'Data', 'Object', 'ImageData'}, name)
end
    -- }}}
    -- Image {{{
local Image = fake 'Image'
Image.__index = Image

function Image.new(width ,height)
    local data
    if type(width) == 'userdata' and width:type() == 'ImageData' then
        data = width -- got ImageData
    else
        data = ImageData.new(width, height)
    end
    if not data then return end
    local image = { data = data }
    local instance = touserdata(data.context)
    debug.setmetatable(instance, {
        __index = setmetatable(image, Image)
    })
    return instance
end

function Image:refresh()
    -- do any pending drawing for the surface
    self.data.object:flush()
    self.data.object:mark_dirty()
end

function Image:getData()
    return self.data
end

function Image:getWidth()
    return self.data.width
end

function Image:getHeight()
    return self.data.height
end

function Image:getDimensions()
    return self.data.width, self.data.height
end

function Image.isCompressed()
    return false
end

function Image:type()
    return "Image"
end

function Image:typeOf(name)
    return not not contains({'Object', 'Drawable', 'Texture', 'Image'}, name)
end
    -- }}}
    -- Canvas {{{
local Canvas = fake 'Canvas'
Canvas.__index = Canvas

function Canvas.new(width, height)
    local data = ImageData.new(width or window.width, height or window.height)
    local canvas = { data = data }
    local instance = touserdata(data.context)
    debug.setmetatable(instance, {
        __index = setmetatable(canvas, Canvas)
    })
    return instance
end

function Canvas:renderTo(func)
    local stashed_context = love_context.cr
    love_context.cr = self.data.context
    func()
    love_context.cr = stashed_context
end

function Canvas:clear(r,g,b,a)
    local cr = self.data.context
    cr:set_source_rgba(r or 0,g or 0,b or 0,a or 0)
    cr:rectangle(0, 0, self.data.width, self.data.height)
    cr:fill()
end

function Canvas:getImageData()
    return self.data
end

function Canvas:getWidth()
    return self.data.width
end

function Canvas:getHeight()
    return self.data.height
end

function Canvas:getDimensions()
    return self.data.width, self.data.height
end

function Canvas:type()
    return "Canvas"
end

function Canvas:typeOf(name)
    return not not contains({'Object', 'Drawable', 'Texture', 'Canvas'}, name)
end
    -- }}}
-- }}}

-- love.event {{{
function love.event.push(event)
    local args = {}
    if event == 'quit' then
        args.type = 'quit'
    end
    -- TODO moar plz
    window:push(event, args)
end
-- }}}

-- love.filesystem {{{
function love.filesystem.isFile(filename)
    return fs.exists(filename)
end
-- }}}

-- love.graphics {{{
local function draw_mode(mode)
    local cr = love_context.cr
    if     mode == 'fill' then cr:fill()
    elseif mode == 'line' then cr:stroke()
    end
end

function love.graphics.clear()
    local cr = love_context.cr
    if love_context.bgcolor[4] then
        cr:set_source_rgba(unpack(love_context.bgcolor))
    else
        cr:set_source_rgb(unpack(love_context.bgcolor))
    end
    love.graphics.rectangle('fill', 0, 0, window.width, window.height)
    -- restore forground color
    if love_context.fgcolor[4] then
        cr:set_source_rgba(unpack(love_context.fgcolor))
    else
        cr:set_source_rgb(unpack(love_context.fgcolor))
    end
end

function love.graphics.rectangle(mode, x, y, width, height)
    local cr = love_context.cr
    cr:rectangle(x, y, width, height)
    draw_mode(mode)
end

function love.graphics.arc(mode, x, y, radius, angle1, angle2, segments)
    local cr = love_context.cr
    cr:new_sub_path()
    cr:arc(x, y, radius, angle1, angle2)
    draw_mode(mode)
end

function love.graphics.circle(mode, x, y, radius, segments)
    love.graphics.arc(mode, x, y, radius, 0, math.rad(360), segments)
end

function love.graphics.line( ... )
    love.graphics.polygon('line', ... )
end

function love.graphics.polygon(mode, ... )
    local cr = love_context.cr
    local points = { ... }
    if type(points[1]) == 'table' then
        points = points[1]
    end
    for i = 1,#points,2 do
        if i == 1 then
            cr:move_to(points[i], points[i+1])
        else
            cr:line_to(points[i], points[i+1])
        end
    end
    cr:close_path()
    draw_mode(mode)
end

function love.graphics.print(text, x, y, r, sx, sy, ox, oy, kx, ky)
    local cr = love_context.cr
    cr:save()
    if x and y then
        cr:move_to(x, y)
    end
    if sx and sy then
        cr:scale(sx, sy)
    end
    if r then
        cr:rotate(r)
    end
    cr:show_text(tostring(text))
    if x and y then
        cr:close_path()
    end
    cr:restore()
end

function love.graphics.setCanvas(canvas)
    if type(canvas) == 'userdata' and canvas:typeOf('Canvas') then
        love_context.cr = canvas.data.context
    elseif not canvas then
        love_context.cr = love_context.screen
    end
end

function love.graphics.setColor(r, g, b, a)
    local color = { r and r/255, g and g/255, b and b/255, a and a/255 }
    local cr = love_context.cr
    if color[4] then
        cr:set_source_rgba(unpack(color))
    else
        cr:set_source_rgb(unpack(color))
    end
    love_context.fgcolor = color
end

function love.graphics.setBackgroundColor(r, g, b, a)
    local color = { r and r/255, g and g/255, b and b/255, a and a/255 }
    love_context.bgcolor = color
end

function love.graphics.origin()
    local cr = love_context.cr
    cr:identity_matrix()
end

function love.graphics.pop()
    local cr = love_context.cr
    cr:restore()
end

function love.graphics.push()
    local cr = love_context.cr
    cr:save()
end

function love.graphics.rotate(angle)
    local cr = love_context.cr
    cr:rotate(angle)
end

function love.graphics.translate(dx, dy)
    local cr = love_context.cr
    cr:translate(dy, dx)
end

function love.graphics.scale(sx, sy)
    local cr = love_context.cr
    cr:scale(sy, sx)
end

function love.graphics.present()
    window.native:blit(window._surface.sdl)
end

function love.graphics.getDimensions()
    return window.width, window.height
end

function love.graphics.draw(drawable, x,y,r,sx,sy,ox,oy,kx,ky)
    if type(drawable) ~= 'userdata' or not drawable:typeOf('Drawable') then
        return
    end
    local cr = love_context.cr
    cr:save()
    if x and y then
        cr:translate(x, y)
    end
    if r then
        cr:rotate(r)
    end
    if sx and sy then
        cr:scale(sx, sy)
    end
    if ox and oy then
        -- TODO
    end
    cr:set_source_surface(drawable.data.object, 0, 0)
    cr:paint()
    cr:restore()
end

function love.graphics.newCanvas(width, height)
    return Canvas.new(width, height)
end

function love.graphics.newImage(width, height)
    return Image.new(width, height)
end
-- }}}

-- love.image {{{
function love.image.newImageData(width, height)
    return ImageData.new(width, height)
end
-- }}}

-- love.math {{{
-- luajit's math.random suite should be fine enough here
love.math.random = math.random
love.math.setRandomSeed = math.randomseed
-- }}}

-- love.mouse {{{
function love.mouse.getPosition()
    return unpack(love_context.mouse)
end

function love.mouse.getX()
    return love_context.mouse[1]
end

function love.mouse.getY()
    return love_context.mouse[2]
end
-- }}}

-- love.window {{{
function love.window.getDimensions() -- deprecated
    return window.width, window.height
end

function love.window.getHeight()
    return window.height
end

function love.window.getWidth()
    return window.width
end

function love.window.getTitle()
    return window.title
end
-- }}}

-- love.window {{{
function love.timer.getDelta()
    return fps.delta
end

fps.accuracy = 2 -- still higher than original love, lol
function love.timer.getFPS()
    return fps.value
end

function love.timer.getTime()
    return process.time()
end

function love.timer.sleep(s)
    process.sleep(s * 1000)
end

function love.timer.step()
    fps:update()
end
-- }}}

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

window:on('close', function ()
    if type(love.quit) == 'function' then
        love.quit()
    end
    process.exit()
end)

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

local c = love.conf
if fs.exists('main.lua') then
    -- load game
    require('./main')
else
    io.stderr:write("no game code (no main.lua found)!\n")
    io.stderr:flush()
    process.exit(1)
    return
end
if type(love.conf) ~= 'function' and fs.exists('./conf.lua') then
    require('./conf')
end
local confok, conferr
if type(love.conf) == 'function' then
    confok, conferr = pcall(love.conf, c)
end

c.window.title  = window.title
c.window.width  = window.width
c.window.height = window.height
love.conf = c

-- initialize cairo
window:surface(function (cairo)
    love_context.screen = cairo.context
    love_context.cr = love_context.screen
    return false -- dont blit immediately
end)

window:on('event', function (event)
    if event.type == window.C.SDL_MOUSEMOTION then
        love_context.mouse[1] = event.motion.x
        love_context.mouse[2] = event.motion.y
    elseif event.type == window.C.SDL_MOUSEBUTTONDOWN then
        local button
        if event.button.button == window.C.SDL_BUTTON_LEFT then
            button = 'l'
        elseif event.button.button == window.C.SDL_BUTTON_MIDDLE then
            button = 'm'
        elseif event.button.button == window.C.SDL_BUTTON_RIGHT then
            button = 'r'
        elseif event.button.button == window.C.SDL_BUTTON_X1 then
            button = 'x1'
        elseif event.button.button == window.C.SDL_BUTTON_X2 then
            button = 'x2'
        else
            button = '?' -- FIXME for now
        end
        love_context.mouse.button = {
            love_context.mouse[1],
            love_context.mouse[2],
            button
        }
    elseif event.type == window.C.SDL_MOUSEBUTTONUP then
        if love_context.mouse.button then
            love_context.mouse.release = true
        end
    end
end)

window:on('need render', function ()

    love.timer.step()
    if type(love.update) == 'function' then
        love.update(love.timer.getDelta())
    end

    if love_context.mouse.button and type(love.mousepressed) == 'function' then
        love.mousepressed(unpack(love_context.mouse.button))
    end
    if love_context.mouse.release then
        if type(love.mousereleased) == 'function' then
            love.mousereleased(unpack(love_context.mouse.button))
        end
        love_context.mouse.release = false
        love_context.mouse.button = nil
    end

    love.graphics.clear()
    love.graphics.origin()
    if type(love.draw) == 'function' then
        love.draw()
    end

    love.graphics.present() -- blit now
    love.timer.sleep(0.0145) -- ~60fps
--     love.timer.sleep(0.0001) -- original love does wait only this long, lol
end)

love.math.setRandomSeed(os.time())
for i=1,3 do love.math.random() end

if type(love.load) == 'function' then
    -- TODO process.argv is missing in threads or passing tables via async/define
    love.load({})
end

end -- emulator
--------------------------------------------------------------------------------

local function emulate(gamepath)
    if love then return end
    if not gamepath then
        io.stderr:write("path to love game missing!\n")
        io.stderr:flush()
        process.exit(1)
        return
    end
    if type(gamepath) == 'number' then
        local  i = gamepath
        gamepath = dirname(process.argv[i])
    end
    process.cwd(gamepath)

    -- love is fake object, that allows all keys to be indexed (recursive) and called
    love = fake 'love'

    local window = Window:new()
    window.scope:import(emulator)
    love.window = window

    local c = love.conf
    if fs.exists('conf.lua') then
        require './conf'
    end
    local confok, conferr
    if type(love.conf) == 'function' then
        confok, conferr = pcall(love.conf, c)
    end

    if type(c.window.title) ~= 'string' then
        c.window.title = "Untitled"
    end
    if type(c.window.width) ~= 'number' then
        c.window.width = 800
    end
    if type(c.window.height) ~= 'number' then
        c.window.height = 600
    end

    return window:open(
        c.window.title,
        c.window.width,
        c.window.height
    )
end

return {
    emulator = emulator,
    emulate  = emulate,
    __main   = function (gamepath)
        emulate(gamepath or process.argv[1])
    end,
}
