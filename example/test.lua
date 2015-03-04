local util = require 'util'

process:on('exit', function (code)
    print(code, "going down …")
end)

process:on('panic', function (err)
    print("PANIC!")
end)

require('jit').opt.start(3)

-- require('encoder').debug('warning')
-- require('encoder').debug('debug')

-- local Scope = require 'scope'
-- local name = "foobar"

-- print "hello world"
-- print(process.cwd())
-- print(require('util').dump(process))
--
-- local ctx = Scope:new()
--
-- ctx:import(function ()
--     print("hello world from the other side", name)
-- end)
--
-- ctx:import(function ()
--     print("foobar", name)
--     local Scope = require 'scope'
--     local ctx = Scope:new()
--     ctx:import(function ()
--         print("LOL", name)
--     end)
--     ctx:call()
-- end)
--
-- ctx:call()

--[[
local Buffer = require 'buffer'

local buf = Buffer:new(1024, 'binary')
-- print(require('util').dump(buf))

local bug = Buffer:new()
bug:copy(buf)
-- print(require('util').dump(bug))]]

local Encoder = require 'encoder'

-- local enc = Encoder:new(process.stdout)
local enc = Encoder:new("test.ogv", {
--     format = 'hd720p 60',
--     format = 'custom',
    width = 1280,
    height = 720,
})
print("output = " .. enc.output .. " in " .. enc.format.width .. "x" .. enc.format.height)
-- for k,v in pairs(enc.settings) do print(k .. util.dump(v)) end

enc.scope:import(function ()
    local x = 0
    encoder:on('frame', function (frame)
        local cr = frame:surface().context
        cr:set_source_rgb(0, 0, 0)
        cr:rectangle(0, 0, frame.width, frame.height)
--         print(cr.status)
        cr:fill()
        require('./samples').quads(cr, 0,0,frame.width, frame.height)
        require('./samples').arc(cr, frame.width*0.5, frame.height*0.5, x)
        x = (x+0.1 - 1) % 100 + 1
    end)

    process.context:on('exit', function ()
        print "close encoder"
    end)
    process:on('panic', function (err)
        print("OMG!PANIC!")
    end)
end)


-- enc.scope:import(function ()
--     encoder:on('data', function (data)
-- --         process.write(process.stdout, data)
-- --         print(data.size)
--     end)
--     encoder:on('frame', function (frame)
--         print(frame.refcount, --frame.format,
--               frame.width, frame.height,
--               frame.components[0].length,
--               frame.components[1].length,
--               frame.components[2].length
--         )
--     end)
-- end)


-- enc.format.transfer_function = ({
--     'tv_gamma',
--     'extended_gamut',
--     'linear',
--     'dci_gamma',
-- })[4]

-- enc.format.width = 42
-- enc.format.chroma_format = '444'
-- enc.format.colour_primaries = 'cinema'
enc.format.colour_primaries = 'hdtv'
enc.settings.rate_control = 'lossless' -- lol, this is the fastest
-- enc.settings.enable_ssim = true
enc.settings.gop_structure = 'intra_only'
enc.settings.enable_deep_estimation = true
enc.settings.enable_zero_estimation = false
enc.settings.enable_global_motion = false


-- for k,v in pairs(getmetatable(enc.settings).__index) do print(k .. util.dump(getmetatable(v).__index)) end

print("luma_offset",      enc.format.luma_offset)
print("luma_excursion",   enc.format.luma_excursion)
print("chroma_offset",    enc.format.chroma_offset)
print("chroma_excursion", enc.format.chroma_excursion)


-- require('./samples').test('arc', enc.format.width, enc.format.height,
--     enc.format.width*0.5, enc.format.height*0.5, 100)
-- require('./samples').test('quads', enc.format.width, enc.format.height,
--     0,0,enc.format.width, enc.format.height)


enc:hook('MODE_DECISION')


local MODES = {'ANALYSE', 'SC_DETECT_1', 'SC_DETECT_2', 'HAVE_GOP',
    'HAVE_PARAMS', 'PREDICT_ROUGH', 'PREDICT_PEL', 'PREDICT_SUBPEL',
    'MODE_DECISION', 'HAVE_REFS', 'HAVE_QUANTS', 'ENCODING',
    'RECONSTRUCT', 'POSTANALYSE', 'DONE'}
for i,mode in ipairs(MODES) do
    local name = string.lower(mode)
    enc:hook(mode)
    print("encoder hooked stage " .. i .. " " .. name .. " …")
    enc.stage[name]:define('tab' ,string.rep('\t',i+2)..' '..i, function ()
        encoder:on('stage', function (frame)
            if frame.frame_number % 50 == 0 then
    --             io.write(_D.tab..encoder.stage.." "..frame.frame_number.."\r")
                io.write(_D.tab.." "..frame.frame_number.."\r")
                io.flush()
            end
        end)
    end)
end


window = require('window'):new()

window.scope:import(function ()
    window:on('close', function ()
        print "window closed …"
    end)
end)

enc.scope:define('window', window.native, function ()
    window = require('window'):cast(_D.window)
    encoder:on('frame', function (frame)
        window:render(frame.raw.components[0].data)
    end)
end)

window:open("test", enc.format.width, enc.format.height)
print "window opened …"


enc.scope:import(function ()
    local io = require 'io'
    local i

    print(require('util').dump(encoder.native.encoder.video_format))
    encoder:on('frame', function (frame)
        i = encoder:push(frame)
        if i % 50 == 0 then
            io.write('\t'..i.." ("..encoder.raw.au_frame..")\r")
            io.flush()
        end
    end)

    process.context.thread:on('stop', function ()
        print "encoder reached end of stream."
    end)
end)
enc:start()
print "encoder started …"



-- local fun = {}
-- for i = 1,10 do
--     local thread = require('thread'):new()
--     fun[i] = thread
--     thread.scope:define('name', string.char(64 + i) .. i, function ()
--         local i = 0
--         thread:on('idle', function ()
--             if i % 1000000 == 0 then print(name, i) end
--             i = i + 1
--         end)
--         thread:on('exit', function ()
--             print("close thread", name)
--         end)
--     end)
--     thread:start()
-- end

