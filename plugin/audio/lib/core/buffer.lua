local ffi = require 'ffi'
local Prototype = require 'prototype'
local doc = require 'util.doc'


local Buffer = Prototype:fork()
Buffer.Audio = nil -- gets filled by Audio (circular dependecy)


function Buffer:init(num_buffers, data, opts)
    if type(num_buffers) ~= 'number' then
        num_buffers, data, opts = nil, num_buffers, data
    end
    if type(data) ~= 'cdata' then
        data, opts = nil, data
    end
    opts = opts or {}
    num_buffers = num_buffers or 1
    self.number = num_buffers
    self.format = opts.format or 'mono16'
    self.frequency = opts.frequency or 44100
    self.format = string.upper(self.format):gsub('%s', '_')

    self.id = ffi.new( "ALuint[?]", self.number)
    Buffer.Audio.C.GenBuffers(self.number, self.id)
    ffi.gc(self.id, function (buffers) -- FIXME cleanup
        Buffer.Audio.C.DeleteBuffers(num_buffers, buffers)
    end)

    if data then
        self:data(data)
    end
end
doc.info(Buffer.init,
        'albuf:init',
        '( [num_buffers=1][, data], opts={ format="MONO16", frequency=44100 } )')

function Buffer:data(i, data)
    if not data then
        i, data = nil, i
    end
    local format = Buffer.Audio.define["AL_FORMAT_" .. self.format]
    if format and data and self.number > 0 then
        Buffer.Audio.C.BufferData(
            self.id[i or 0],
            tonumber(format),
            data,
            ffi.sizeof(data),
            self.frequency
        )
    end
end
doc.info(Buffer.data, 'albuf:data', '( [i=0], data )')


return Buffer

