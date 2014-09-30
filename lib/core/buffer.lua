local Prototype = require 'prototype'

local Buffer = Prototype:fork()

_it.loads('Buffer')
function Buffer:init(size, encoding)
    if type(size) == 'string' then
        size, encoding = nil, size
    end
    self.encoding = encoding
    self._buffer = _it.buffers()
    if size then
        self.size = size
        self._buffer:malloc(size)
    end
end

function Buffer:setEncoding(encoding)
    self.encoding = encoding
end

return Buffer
