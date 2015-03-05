local cdef = require 'cdef'
local Scope = require 'scope'
local Metatype = require 'metatype'
local _ffi = require 'util._ffi'
local doc = require 'util.doc'


local Thread = require(process.context and 'events' or 'prototype'):fork()
Thread.type = Metatype:struct("it_threads", cdef)

Thread.type:load(_it.api('api'), {
    __ref = 'it_refs',
    __unref = 'it_unrefs',
    __ac = 'it_allocs_thread',
    __init = 'it_inits_thread',
    safe = 'it_safes_thread',
    join = 'it_joins_thread',
    stop = 'it_stops_thread',
    create = 'it_creates_thread',
    __gc = 'it_frees_thread',
}, cdef)


function Thread:__new(name)
    if self.prototype.__new then self.prototype.__new(self) end
    local name = _ffi.toname(self.reference, name)
    self.stop = nil
    self.exit = true
    self.scope = Scope:new(name .. ".scope")
    self.reference = self.type:create(nil, self.scope.state)
    self.raw = self.reference.thread
    self.reference.name = name
    -- special case since object gets injected into process.context instead as global
    self.scope:define('_it_threads_', self.reference, function ()
        process.context.thread = require('thread'):cast(
            _D._it_threads_, process.context.scope)
    end)
end
doc.info(Thread.__new, 'Thread:new', '( [name=ptr(reference)] )')

function Thread:__cast(pointer)
    if self.prototype.__new then self.prototype.__new(self) end
    self.reference = self.type:ptr(pointer)
    self.raw = self.reference.thread
    self.scope = scope or Scope:cast(self.reference.ctx)
    self.start = nil
end
doc.info(Thread.__cast, 'Thread:cast', '( pointer[, scope] )')

function Thread:start()
    if self.reference.closed == 0 then return self end
    process.shutdown = false -- prevent process from shutting down
    if not self._bound_join then
        local thread = self
        process:on('exit', function ()
            if  thread.exit then
                thread:join()
            end
        end)
        self._bound_join = true
    end
    self.reference:create()
    return self
end
doc.info(Thread.start, 'thread:start', '(  )')

function Thread:join()
    self.reference:join()
    return self
end
doc.info(Thread.join, 'thread:join', '(  )')

function Thread:safe(safe)
    if safe == nil then safe = true end
    self.reference:safe(not not safe)
    self.scope:safe(not not safe)
    return self
end
doc.info(Thread.safe, 'thread:safe', '( nil=true|true|false )')

function Thread:stop()
    self.reference:stop()
    self.reference = nil
    self.raw = nil
end
doc.info(Thread.stop, 'thread:stop', '(  )')


return Thread


