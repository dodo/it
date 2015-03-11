local ffi = require 'ffi'
local cdef = require 'cdef'
local _ffi = require 'util._ffi'
local Prototype = require 'prototype'
local Metatype = require 'metatype'
local doc = require 'util.doc'


local Scope = Prototype:fork()
Scope.type = Metatype:struct("it_states", cdef)

Scope.type:api("Scope", {'import', 'define'})
Scope.type:load(_it.api('api'), {
    __ref = 'it_refs',
    __unref = 'it_unrefs',
    __ac = 'it_allocs_scope',
    __init = 'it_inits_scope',
    collectgarbage = 'it_collectsgarbage_scope',
    defcdata = 'it_defines_cdata_scope',
    close = 'it_closes_scope',
    call = 'it_calls_scope',
    __gc = 'it_frees_scope',
}, cdef)
-- Scope.type.prototype.defcdata = _ffi.get_define() -- HACK share pointer here


function Scope:__new(name)
    self.state = self.type:create(nil, _D._it_processes_)
    self.state.name = _ffi.toname(self, name)
    self.raw = self.state.lua
    if process.verbose then
        self:import(function () process.verbose = true end)
    end
    if process.debugmode then
        self:import(function () process.debug() end)
    end
    if process.debugger then
        self:import(function () process.debug('remote') end)
    end
    -- special case since object gets injected into process.context instead as global
    self:define('_it_scopes_', self.state, function ()
        process.context.scope = require('scope'):cast(_D._it_scopes_)
    end)
end
doc.info(Scope.__new, 'Scope:new', '( [name=ptr(state)] )')

function Scope:__cast(pointer)
    self.state = self.type:ptr(pointer)
    self.raw = self.state.lua
end
doc.info(Scope.__cast, 'Scope:cast', '( pointer )')

function Scope:import(lua_function)
    self.state:import(lua_function)
    if self.state.err == nil then return self end
    self:error("scope:import")
end
doc.info(Scope.import, 'scope:import', '( lua_function )')

function Scope:define(name, data, import)
    if type(data) == 'cdata' then
        self.state:defcdata(name, data)
    else
        self.state:define(name, data)
    end
    if import then
        self:import(import)
    end
    return self
end
doc.info(Scope.define, 'scope:define', '( name, data[, import] )')

function Scope:safe(safe)
    if safe == nil then safe = true end
    self.state.safe = not not safe
    return self
end
doc.info(Scope.safe, 'scope:safe', '( nil=true|true|false )')

function Scope:run()
    self.state:call()
    if self.state.err == nil then return self end
    self:error("scope:run")
end
doc.info(Scope.run, 'scope:run', '(  )')

function Scope:error(msg)
    local format, str, ctx = string.format, ff.string, self.state
    error(format("error in scope %s: %s %s", str(ctx.name), msg, str(ctx.err)))
end
doc.info(Scope.error, 'scope:error', '( message )')

function Scope:close()
    self.state:close()
end
doc.info(Scope.close, 'scope:close', '(  )')

return Scope
