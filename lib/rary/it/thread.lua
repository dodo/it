local cdef = require 'cdef'
local Scope = require 'scope'
local Metatype = require 'metatype'
local doc = require 'util.doc'


local Thread = require(context and 'events' or 'prototype'):fork()
Thread.type = Metatype:struct("it_threads", cdef)

Thread.type:load('libapi.so', {
    ref = 'it_refs',
    unref = 'it_unrefs',
    init = 'it_inits_thread',
    safe = 'it_safes_thread',
    create = 'it_creates_thread',
    close = 'it_closes_thread',
    __gc = 'it_frees_thread',
}, cdef)


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
doc.info(Thread.init, 'thread:init', '( [pointer] )')

function Thread:start()
    process.shutdown = false -- prevent process from shutting down
    self.reference:create()
end
doc.info(Thread.start, 'thread:start', '(  )')

function Thread:join()
    -- TODO
end
doc.todo(Thread.join, 'thread:join', '(  )')

function Thread:safe(safe)
    if safe == nil then safe = true end
    self.reference:safe(not not safe)
    self.scope:safe(not not safe)
end
doc.info(Thread.safe, 'thread:safe', '( nil=true|true|false )')

function Thread:close()
    self.reference:close()
    self.reference = nil
end
doc.info(Thread.close, 'thread:close', '(  )')


return Thread


