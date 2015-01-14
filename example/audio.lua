local ffi = require 'ffi'
local Audio = require 'audio'
local clamp = require('util.misc').clamp

function process.load()
--if process.debugger then require('mobdebug').start() require('mobdebug').off() end

math.randomseed(os.time())

process:on('exit', function (code)
    print(code, "going down …")
end)


SPF = 3 -- milliseconds per frame
BUFFER_SIZE = 440*SPF
NUM_BUFFERS = 5


mydata = ffi.new("int16_t[?]", BUFFER_SIZE)


print "init audio"
audio = Audio:new()
buffer = Audio.Buffer:new()
-- print(require('util').dump(buffer))


print "Generate sinusoidal test signal"
sinusoidal(440)


-- do print "short test …"
--     local buf = Audio.Buffer:new(NUM_BUFFERS)
--     for i=0,NUM_BUFFERS-1 do
--         buf:data(i, mydata)
--     end
--     buffer:data(mydata)
--     audio:push(buf)
    audio:push(buffer)
    audio:play()
-- end
end

function sinusoidal(f)
    local m = 2*math.pi/buffer.frequency*f
    for i=0 , BUFFER_SIZE-1 do
        mydata[i] = clamp((2^15 - 1)*math.sin(m*i), -32768, 32767)
    end
end
function cosinusoidal(f)
    local m = 2*math.pi/buffer.frequency*f
    for i=0 , BUFFER_SIZE-1 do
        mydata[i] = clamp((2^15 - 1)*math.cos(m*i), -32768, 32767)
    end
end

function havefun(f)
    local m = 2*math.pi/buffer.frequency*f
    for i=0 , BUFFER_SIZE-1 do
        mydata[i] = clamp((2^15 - 1)*math.tan(m*i), -32768, 32767)
    end
end

function process.setup()
    print "start loop …"
    freq = 400
    generate_my_data = sinusoidal
    --generate_my_data = cosinusoidal
    --generate_my_data = havefun
    n, val = n or 0
    progress = progress or 0
    time = os.clock()
end

function process.loop()
    val = audio:source('buffers processed')
    if val > 0 then
            audio:pop(buffer)

        --freq = freq * math.abs(math.sin(n)*2) + 0.5
--         freq = freq * (math.random() + math.abs(math.sin(n)))
--         print(freq)

        generate_my_data(freq)
--         for i=val , 1 , -1 do
            buffer:data(mydata)
            audio:push(buffer)

            progress = progress + BUFFER_SIZE / buffer.frequency
            io.write(string.format("  played %f seconds @time %f [%f]       \r",
                                   progress, os.clock() - time, freq))
            io.flush()
--         end
        if audio:source('source state') ~= 0x1012--[[AL_PLAYING]] then -- FIXME
--             print("UNDERRUN")
            audio:play()
        end
    end
    n = n + 0.01
    if n > math.pi * 2 then
        n = 0
    end
--     process.sleep(1)
--     collectgarbage()
end
