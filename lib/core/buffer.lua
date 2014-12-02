local ffi = require 'ffi'
local Prototype = require 'prototype'
local Metatype = require 'metatype'
local doc = require 'util.doc'

ffi.cdef [[
    void *malloc(size_t size);
    void free(void *ptr);
]]

local Buffer = Prototype:fork()
Buffer.type = Metatype:typedef('void*')


function Buffer:init(data, length, encoding)
    if type(data) == 'number' then
        data, length, encoding = nil, data, length
    end
    if type(length) == 'string' then
        length, encoding = nil, length
    end
    if type(data) == 'userdata' or type(data) == 'cdata' then
        encoding = encoding or 'cdata'
    end
    self.free = false
    self.encoding = encoding
    if data then
        if length then self.length = length end
        self.data = self.type:new(data)
    elseif length then
        self:malloc(length)
    end
end
doc.info(Buffer.init, 'buffer:init', '( data[, length[, encoding]] )') -- FIXME

function Buffer:malloc(length)
    self.free = true
    self.length = length
    self.data = ffi.gc(self.type:new(ffi.C.malloc(length)), ffi.C.free)
end
doc.info(Buffer.malloc, 'buffer:malloc', '( length )')

function Buffer:setEncoding(encoding)
    self.encoding = encoding
end
doc.info(Buffer.setEncoding, 'buffer:setEncoding', '( [encoding] )')

function Buffer:copy(buffer)
    if not buffer or not buffer.length then return end
    if not self.length then
        self:malloc(buffer.length)
    end
    self.encoding = buffer.encoding
    ffi.copy(self.data, buffer.data, self.length)
end
doc.info(Buffer.copy, 'buffer:copy', '( buffer )')

return Buffer
