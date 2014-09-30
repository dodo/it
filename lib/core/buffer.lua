local Prototype = require 'prototype'

local Buffer = Prototype:fork()

_it.loads('Buffer')
function Buffer:init(data, size, encoding)
    if type(data) == 'number' then
        data, size, encoding = nil, data, size
    end
    if type(size) == 'string' then
        size, encoding = nil, size
    end
    if type(data) == 'userdata' then
         encoding = encoding or 'userdata'
    end
    self.encoding = encoding
    self._buffer = _it.buffers()
    if data then
        if size then self.size = size end
        self._buffer:user(data, size)
    elseif size then
        self.size = size
        self._buffer:malloc(size)
    end
end

function Buffer:setEncoding(encoding)
    self.encoding = encoding
end

function Buffer:copy(buf)
    if not buf or not buf.size then return end
    if not self.size then
        self.size = buf.size
        self._buffer:malloc(buf.size)
    end
    self.encoding = buf.encoding
    -- dest:memcpy(src, dest.size)
    self._buffer:memcpy(buf._buffer, self.size)
end

return Buffer
