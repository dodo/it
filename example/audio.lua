local ffi = require 'ffi'
local Audio = require 'audio'


process:on('exit', function (code)
    print(code, "going down …")
end)


BUFFER_SIZE = 440*100
NUM_BUFFERS = 5


mydata = ffi.new("int16_t[?]", BUFFER_SIZE)


print "init audio"
audio = Audio:new()
buffer = Audio.Buffer:new()
-- print(require('util').dump(buffer))


print "Generate sinusoidal test signal"
local m = 2*math.pi/buffer.frequency*440
for i=0 , BUFFER_SIZE-1 do
    mydata[i]=(2^15-1)*math.sin(m*i)
end


do print "short test …"
    local buf = Audio.Buffer:new(NUM_BUFFERS)
    for i=0,NUM_BUFFERS-1 do
        buf:data(i, mydata)
    end
    buffer:data(mydata)
    audio:push(buf)
    audio:push(buffer)
    audio:play()
end


print "start loop …"
local n, val = 0
local progress = 0
local time = os.clock()
return function ()
    val = audio:source('buffers processed')
    if val > 0 then
        for i=val , 1 , -1 do
            audio:pop(buffer)
            buffer:data(mydata)
            audio:push(buffer)

            progress = progress + BUFFER_SIZE / buffer.frequency
            io.write(string.format("  played %f seconds @time %f\r",
                                   progress, os.clock() - time))
            io.flush()
        end
        if audio:source('source state') ~= 0x1012--[[AL_PLAYING]] then -- FIXME
            print("UNDERRUN")
            audio:play()
        end
    end
    collectgarbage()
    process.sleep(1)
end
