local Prototype = require 'prototype'

local Buffer = Prototype:fork()

_it.loads('Buffer')
function Buffer:init(data, length, encoding)
    if type(data) == 'number' then
        data, length, encoding = nil, data, length
    end
    if type(length) == 'string' then
        length, encoding = nil, length
    end
    if type(data) == 'userdata' then
         encoding = encoding or 'userdata'
    end
    self.encoding = encoding
    self._buffer = _it.buffers()
    if data then
        if length then self.length = length end
        self._buffer:user(data, length)
    elseif length then
        self.length = length
        self._buffer:malloc(length)
    end
end

function Buffer:setEncoding(encoding)
    self.encoding = encoding
end

function Buffer:copy(buf)
    if not buf or not buf.length then return end
    if not self.length then
        self.length = buf.length
        self._buffer:malloc(buf.length)
    end
    self.encoding = buf.encoding
    -- dest:memcpy(src, dest.length)
    self._buffer:memcpy(buf._buffer, self.length)
end

return Buffer
