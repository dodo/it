local ffi = require 'ffi'
local Audio = require 'audio'
local clamp = require('util.misc').clamp
local Fps = require 'util.fps'

function process.load()

math.randomseed(os.time())

process:on('exit', function (code)
    print(code, "going down …")
end)


SPF = 2 -- milliseconds per frame
BUFFER_SIZE = 440*SPF
--NUM_BUFFERS = 5


mydata = {}
for i = 1,1 do
    mydata[i] = ffi.new("int16_t[?]", BUFFER_SIZE*i)
end
print('number of data:', #mydata)


print "init audio"
fps = Fps:new()
audio = Audio:new()
buffers = {}
for i = 1,#mydata do
    buffers[i] = Audio.Buffer:new()
end
-- print(require('util').dump(buffer))


print "Generate sinusoidal test signal"
for i = 1,#mydata do
    sinusoidal(i, 440)
end


-- do print "short test …"
--     local buf = Audio.Buffer:new(NUM_BUFFERS)
--     for i=0,NUM_BUFFERS-1 do
--         buf:data(i, mydata)
--     end
--     buffer:data(mydata)
--     audio:push(buf)
    for i,data in ipairs(mydata) do
--        buffers[i]:data(data)
        audio:push(buffers[i])
    end
    audio:play()
-- end

end

function sinusoidal(n,f)
    local m = 2*math.pi/buffers[n].frequency*f
    for i=0 , BUFFER_SIZE*n-1 do
        mydata[n][i] = clamp((2^15 - 1)*math.sin(m*i), -32768, 32767)
    end
end
function cosinusoidal(n,f)
    local m = 2*math.pi/buffers[n].frequency*f
    for i=0 , BUFFER_SIZE*n-1 do
        mydata[n][i] = clamp((2^15 - 1)*math.cos(m*i), -32768, 32767)
    end
end

function havefun(n,f)
    local m = 2*math.pi/buffers[n].frequency*f
    for i=0 , BUFFER_SIZE*n-1 do
        mydata[n][i] = clamp((2^15 - 1)*math.tan(m*i), -32768, 32767)
    end
end

function process.setup()
    print "start loop …"
    freqs = {
        91*9,
     --   54*16,
        66*13,--math.random(),
--        170*53,
--        291*20,
        21*11,
        51*12,
--        80*25,
--        49*22,
--        75*36,
--        87*30,
--        134*43,
--        82*103,
--        134*5,
    }
--    freq = 581
    generate_my_data = sinusoidal
--    generate_my_data = cosinusoidal
--    generate_my_data = havefun
    n, freqn, val = n or 0, freqn or 1
    progress = progress or 0
    time = os.clock()
end

function process.loop()
    fps:update()
    val = audio:source('buffers processed')
--    print('loop', val)
    if val > 0 then

        --freq = freq * math.abs(math.sin(n)*2) + 0.5
--         freq = freq * (math.random() + math.abs(math.sin(n)))
--         print(freq)
            local freq = freqs[freqn]
            for i,data in ipairs(mydata) do
                audio:pop(buffers[i])
                generate_my_data(i,freq)
--         for i=val , 1 , -1 do
                buffers[i]:data(data)
                audio:push(buffers[i])
                progress = progress + BUFFER_SIZE*i / buffers[i].frequency
            end
        freqn = freqn + 1
        if freqn > #freqs then
            freqn = 1
        end

            io.write(string.format("  [%f fps]  played %f seconds @time %f [%f]       \r",
                                   fps.value, progress, os.clock() - time, freq))
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
--    process:sleep(100) -- should be ~10fps
--     process.sleep(1)
--     collectgarbage()
end
