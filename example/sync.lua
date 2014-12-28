local Async = require 'async'

local width, height = 600,600

window = require('window'):new()
window.async = Async:new(window.thread)


window.scope:import(function ()
--     context.thread:safe(false)
    math.randomseed(os.time() - 1)

--     local COUNT = {x=4,y=4}
    local COUNT = {x=2,y=2}


    local Async = require 'async'
    local Thread = require 'thread'
    local width, height = window.width, window.height
    local w, h = math.floor(width/(COUNT.x)), math.floor(height/(COUNT.y))
    window.async = context.async
    print(width .. "x" .. height)
    COUNT.i = COUNT.x * COUNT.y


function threaded()
--     context.thread:safe(false)
    math.randomseed(os.time() + id)

    local x = 0
    local api = context.async
    local id, width, height = _D.id, _D.width, _D.height
    local surface = require('lib.cairo').surface('ARGB32', width, height)
    print(id, width .. "x" .. height)
    api:on('render', function ()
        surface.context:set_source_rgb(math.random(),math.random(),math.random())
        surface.context:rectangle(0,0,width,height)
        surface.context:fill()
        require('./samples').arc(surface.context, width/2,height/2, x)
        surface.object:flush()
        surface.object:mark_dirty()
        process:sleep(math.random(520) + 500)
        backport:send('result', id, surface.object)
--         x = (x+0.1 - 1) % 100 + 1
        x = x % (width/2) + 1
    end)
    context:on('exit', function ()
        print("close thread", id)
        context.thread:close()
    end)
-- require('util.luastate').dump_stats(io.stderr)
    backport:send('ready', id)
end


function torched()
--     context.thread:safe(false)
    local cairo = require 'lib.cairo'
    local api = context.async
    local id, width, height = _D.id, _D.width, _D.height
    math.randomseed(os.time() + id)
    print(id, width .. "x" .. height)
    ----------------------------------------------------------------------------
    package.env('vanilla')
    require 'torch'
    require 'camera'
    local surface, data, frame, pixels
    local cam = image.Camera{} -- /dev/video0
    local pixels = torch.DoubleTensor(4, cam.height, cam.width)
--     local pixels = torch.DoubleTensor(cam.width, cam.height, 4)
--     pixels[4] = 1
--     pixels[{ {},{}, 4 }] = 1
--     pixels[{ {},{}, 1 }] = 1
    api:on('render', function ()
--         pixels = torch.DoubleTensor(4, cam.height, cam.width)
--         pixels:zero()
--         pixels[4]:fill(0)
        frame = cam:forward()
--         pixels[1] = frame
        pixels[{ {1,3} }] = frame
--         pixels[{1,3}] = frame
--         print(frame:size())
        data = image.scale(pixels, width, height)
        data.image.saturate(data)
        data = data:mul(255):byte():data()
        -- TODO need to add alpha channel + scale it up
        surface = cairo.surface_from(data, 'RGB24', width, height, width * 4)
        process:sleep(100) -- should be ~10fps
        backport:send('result', id, surface.object)
    end)
    context:on('exit', function ()
        print("close thread", id)
        cam:stop()
        context.thread:close()
    end)
    backport:send('ready', id)
end


    tasks = {}
    window.async:on('result', function (id, surface)
--         io.write('result ' .. id .. '\r') io.flush()
        window:surface(function (image)
            -- TODO FIXME make faster with pixman
            local x =  (id-1) * w % width
            local y = math.floor(((id-1) * w - x) / width)
            local x, y = unpack(threads[id].coords)
            image.context:set_source_surface(surface, x, y)
            image.context:paint()
        end)
        threads[id].async:send('render')
    end)


    threads = {}
    window.async:on('ready', function (id)
        print("start render", id)
        threads[id].async:send('render')
    end)

    local coords = {x=0, y=0}
    for i = 1,COUNT.i do
        local thread = Thread:new()
        thread.async = Async:new(thread)
        thread.coords = {coords.x, coords.y}
        thread.scope:define('backport', window.async.native, function ()
            backport = require('async'):new(nil, _D.backport)
        end)
        thread.scope:define('window', window.native, function ()
            window = require('window'):new(_D.window)
        end)
        thread.scope:define('height', h)
        thread.scope:define('width',  w)
        thread.scope:define('id',     i)
        if torched and (math.random(9) == 1 or i == COUNT.i) then
            thread.scope:import(torched)
            torched = nil
        else
            thread.scope:import(threaded)
        end
        table.insert(threads, thread)
        thread:start()
        coords.x = coords.x + w
        if coords.x >= width then
            coords.x = 0
            coords.y = coords.y + h
        end
    end
end)

window:open("sync", width, height)

-- require('util.luastate').dump_stats(io.stderr)
