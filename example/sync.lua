local Async = require 'async'

local width, height = 600,600

window = require('window'):new()
window.async = Async:new(window.thread)


window.scope:import(function ()
    context.thread:safe(false)
    local Async = require 'async'
    local Thread = require 'thread'
    local COUNT = {x=4,y=4}
    local width, height = window.width, window.height
    local w, h = math.floor(width/(COUNT.x)), math.floor(height/(COUNT.y))
    window.async = context.async
    print(width .. "x" .. height)
    COUNT.i = COUNT.x * COUNT.y;


function threaded()
    context.thread:safe(false)
    local x = 0
    local api = context.async
    local id, width, height = _D.id, _D.width, _D.height
    local surface = require('cairo').surface('ARGB32', width, height)
    math.randomseed(os.time() + id)
    print(id, width .. "x" .. height)
    api:on('render', function ()
        surface.context:set_source_rgb(math.random(),math.random(),math.random())
        surface.context:rectangle(0,0,width,height)
        surface.context:fill()
        require('./samples').arc(surface.context, width/2,height/2, x)
        surface.object:flush()
        surface.object:mark_dirty()
--         process:sleep(math.random(20))
        backport:send('result', id, surface.object)
--         x = (x+0.1 - 1) % 100 + 1
        x = x % (width/2) + 1
    end)
    backport:send('ready', id)
end


    tasks = {}
    context.async:on('result', function (id, surface)
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
    context.async:on('ready', function (id)
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
        thread.scope:import(threaded)
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

