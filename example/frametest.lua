local ffi = require 'ffi'
local Frame = require 'encoder.frame'
-- local Encoder = require 'encoder'

local width = 352
local height = 240

-- Encoder:new(false):debug('debug')
-- ffi.cdef("void it_sets_schro_debug_level(int level);")
-- ffi.C.it_sets_schro_debug_level(4)


print "first frame ---------------------------"
a = Frame:new(width, height, 'ARGB')
print "get context ---------------------------"
local cr = a:surface().context
print "draw samples ---------------------------"
require('./samples').quads(cr, 0,0,a.width, a.height)
require('./samples').arc(cr, a.width*0.5, a.height*0.5, 100)
a:render()
print "convert to u8 444 ---------------------------"
b = a:new_convert('u8 444')
print "convert to u8 420 ---------------------------"
c = b:new_convert('u8 420')
for k,v in pairs({c:buffer()}) do print(k .. require('util').dump(v)) end
print "convert to u8 444 ---------------------------"
d = c:new_convert('u8 444')
print "convert to argb ---------------------------"
e = d:new_convert('argb')


-- for k,v in pairs({a:buffer()}) do print('a' .. k .. require('util').dump(v)) end
-- for k,v in pairs({b:buffer()}) do print('b' .. k .. require('util').dump(v)) end
-- for k,v in pairs({c:buffer()}) do print('c' .. k .. require('util').dump(v)) end
-- for k,v in pairs({d:buffer()}) do print('d' .. k .. require('util').dump(v)) end
-- for k,v in pairs({e:buffer()}) do print('e' .. k .. require('util').dump(v)) end


for i,frame in ipairs({a,b,c,d,e}) do
    print(i,"write to png",frame, frame.raw.refcount)
    frame:write_to_png("frametest_" .. i .. ".png")
end

