local cdef = require 'cdef'
local Thread = require 'thread'
local Metatype = require 'metatype'
local doc = require 'util.doc'


local Async = require('events'):fork()
Async.type = Metatype:struct("it_asyncs", cdef)

Async.type:api("Async", {'push'})
Async.type:load('libapi.so', {
    ref = 'it_refs',
    unref = 'it_unrefs',
    init = 'it_inits_async',
    newqueue = 'it_queues_async',
    pushcdata = 'it_pushes_cdata_async',
    send = 'it_sends_async',
    __gc = 'it_frees_async',
}, cdef)


function Async:init(thread, pointer)
    if self.prototype.init then self.prototype.init(self) end
    if pointer then
        -- do init here since only here the right uvloop exists
        self.native = self.type:create(pointer)
        self.thread = (pointer == _D._it_asyncs_) and
                context.thread or Thread:new(self.native.thread)
        return
    end
    self.thread = thread or Thread:new()
    self.native = self.type:new()
    self.native.thread = self.thread.reference
    -- special case since object gets injected into context instead as global
    self.thread.scope:define('_it_asyncs_', self.native, function ()
        context.async = require('async'):new(nil, _D._it_asyncs_)
    end)
end
doc.info(Async.init, 'async:init', '( thread|nil[, pointer] )')

function Async:send(event, ...)
    local queue = self.native:newqueue()
    for _, value in ipairs({...}) do
        -- TODO copy functions
        if type(value) == "cdata" then
            self.native.pushcdata(queue, value)
        else
            self.native.push(queue, value)
        end
    end
    self.native:send(event, queue)
end
doc.info(Async.send, 'async:send', '( event[, ...] )')
jit.off(Async.send)

return Async
