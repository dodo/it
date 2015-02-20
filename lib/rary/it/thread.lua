local cdef = require 'cdef'
local Scope = require 'scope'
local Metatype = require 'metatype'
local doc = require 'util.doc'


local Thread = require(process.context and 'events' or 'prototype'):fork()
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


function Thread:__new()
    if self.prototype.__new then self.prototype.__new(self) end
    self.close = nil
    self.scope = Scope:new()
    self.reference = self.type:create(nil, self.scope.state)
    self.raw = self.reference.thread
    -- special case since object gets injected into process.context instead as global
    self.scope:define('_it_threads_', self.reference, function ()
        process.context.thread = require('thread'):cast(
            _D._it_threads_, process.context.scope)
    end)
end
doc.info(Thread.__new, 'Thread:new', '(  )')

function Thread:__cast(pointer)
    if self.prototype.__new then self.prototype.__new(self) end
    self.reference = self.type:ptr(pointer)
    self.raw = self.reference.thread
    self.scope = scope or Scope:cast(self.reference.ctx)
    self.start = nil
end
doc.info(Thread.__cast, 'Thread:cast', '( pointer[, scope] )')

function Thread:start()
    process.shutdown = false -- prevent process from shutting down
    self.reference:create()
    return self
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
    return self
end
doc.info(Thread.safe, 'thread:safe', '( nil=true|true|false )')

function Thread:close()
    self.reference:close()
    self.reference = nil
end
doc.info(Thread.close, 'thread:close', '(  )')


return Thread


