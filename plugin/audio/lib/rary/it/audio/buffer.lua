local ffi = require 'ffi'
local Prototype = require 'prototype'
local doc = require 'util.doc'


local Buffer = Prototype:fork()
Buffer.Audio = nil -- gets filled by Audio (circular dependecy)


function Buffer:__new(num_buffers, data, opts)
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
doc.info(Buffer.__new,
        'Buffer:new',
        '( [num_buffers=1][, data], ' ..
        'opts={ format="MONO16", frequency=44100 } )')

function Buffer:data(i, data, length)
    if type(i) ~= 'number' then
        i, data, length = nil, i, data
    end
    local format = Buffer.Audio.define["AL_FORMAT_" .. self.format]
    if format and data and self.number > 0 then
        length = length or ffi.sizeof(data)
        Buffer.Audio.C.BufferData(
            self.id[i or 0], tonumber(format),
            data, length, self.frequency
        )
    end
end
doc.info(Buffer.data, 'albuf:data', '( [i=0], data )')


return Buffer

