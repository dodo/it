local ffi = require 'ffi'
local Scope = require 'scope'
local Metatype = require 'metatype'

ffi.cdef[[
    typedef size_t uv_thread_t;
    typedef size_t uv_idle_t;
    typedef void (*uvI_thread_callback) (void *priv);
]]


local Thread = require(context and 'events' or 'prototype'):fork()
Thread.type = Metatype:struct("it_threads", {
    "int refc";
    "it_states *ctx";
    "uv_thread_t *thread";
    "uv_idle_t *idle";
    "uvI_thread_callback on_init";
    "uvI_thread_callback on_idle";
    "uvI_thread_callback on_free";
    "bool closed";
    "void *priv";
})

Thread.type:load('libapi.so', {
    ref = [[int it_refs(it_threads* ref)]];
    unref = [[int it_unrefs(it_threads* ref)]];
    init = [[void it_inits_thread(it_threads* thread, it_states* ctx)]];
    safe = [[void it_safes_thread(it_threads* thread, bool safe)]];
    create = [[void it_creates_thread(it_threads* thread)]];
    close = [[void it_closes_thread(it_threads* thread)]];
    __gc = [[void it_frees_thread(it_threads* thread)]];
})


function Thread:init(pointer)
    if self.prototype.init then self.prototype.init(self) end
    if pointer then
        self.reference = self.type:ptr(pointer)
        self.raw = self.reference.thread
        self.scope = (pointer == _D._it_threads_) and
                context.scope or Scope:new(self.reference.ctx)
        self.start = nil
        return
    end
    self.close = nil
    self.scope = Scope:new()
    self.reference = self.type:create(nil, self.scope.state)
    self.raw = self.reference.thread
    -- special case since object gets injected into context instead as global
    self.scope:define('_it_threads_', self.reference, function ()
        context.thread = require('thread'):new(_D._it_threads_)
    end)
end

function Thread:start()
    process.shutdown = false -- prevent process from shutting down
    self.reference:create()
end

function Thread:join()
    -- TODO
end

function Thread:safe(safe)
    if safe == nil then safe = true end
    self.reference:safe(not not safe)
end

function Thread:close()
    self.reference:close()
    self.reference = nil
end


return Thread


