local cdef = require 'cdef'
local Thread = require 'thread'
local Metatype = require 'metatype'
local doc = require 'util.doc'


local Async = require('events'):fork()
Async.type = Metatype:struct("it_asyncs", cdef)

Async.type:api("Async", {'push'})
Async.type:load(_it.api('api'), {
    __ref = 'it_refs',
    __unref = 'it_unrefs',
    __ac = 'it_allocs_async',
    __init = 'it_inits_async',
    newqueue = 'it_queues_async',
    pushcdata = 'it_pushes_cdata_async',
    send = 'it_sends_async',
    __gc = 'it_frees_async',
}, cdef)


function Async:__new(thread)
    if self.prototype.__new then self.prototype.__new(self) end
    self.thread = thread or Thread:new()
    self.native = self.type:new()
    self.native.thread = self.thread.reference
    -- special case since object gets injected into process.context instead as global
    self.thread.scope:define('_it_asyncs_', self.native, function ()
        process.context.async = require('async'):cast(
            _D._it_asyncs_, process.context.thread)
    end)
end
doc.info(Async.__new, 'Async:new', '( thread|nil )')

function Async:__cast(pointer, thread)
    if self.prototype.__new then self.prototype.__new(self) end
    -- do init here since only here the right uvloop exists
    self.native = self.type:create(pointer)
    self.thread = thread or Thread:cast(self.native.thread)
end
doc.info(Async.__cast, 'Async:cast', '( pointer[, thread] )')

function Async:send(event, ...)
    local queue = self.native:newqueue()
    for _, value in ipairs({...}) do
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
