local ffi = require 'ffi'
local Thread = require 'thread'
local Metatype = require 'metatype'
local doc = require 'util.doc'

ffi.cdef[[
    typedef size_t it_queues;
    typedef size_t uv_async_t;
    typedef size_t uv_mutex_t;
    typedef void (*uvI_async_callback) (void *priv, it_queues* queue);
]]


local Async = require('events'):fork()
Async.type = Metatype:struct("it_asyncs", {
    "int refc";
    "it_threads *thread";
    "uv_async_t *async";
    "uv_mutex_t *mutex";
    "it_queues  *queue";
    "it_queues  *last";
    "uvI_async_callback on_sync";
    "void* priv";
})

Async.type:api("Async", {'push'})
Async.type:load('libapi.so', {
    ref = [[int it_refs(it_asyncs* ref)]];
    unref = [[int it_unrefs(it_asyncs* ref)]];
    init = [[void it_inits_async(it_asyncs* async)]];
    newqueue = [[it_queues* it_queues_async(it_asyncs* async)]];
    pushcdata = [[void it_pushes_cdata_async(it_queues* queue, void* cdata)]];
    send = [[void it_sends_async(it_asyncs* async, const char* key, it_queues* queue)]];
    __gc = [[void it_frees_async(it_asyncs* async)]];
})


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
