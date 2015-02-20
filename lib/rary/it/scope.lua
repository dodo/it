local ffi = require 'ffi'
local cdef = require 'cdef'
local _ffi = require 'util._ffi'
local Prototype = require 'prototype'
local Metatype = require 'metatype'
local doc = require 'util.doc'


local Scope = Prototype:fork()
Scope.type = Metatype:struct("it_states", cdef)

Scope.type:api("Scope", {'import', 'define'})
Scope.type:load('libapi.so', {
    ref = 'it_refs',
    unref = 'it_unrefs',
    collectgarbage = 'it_collectsgarbage_scope',
--     defcdata = 'it_defines_cdata_scope',
    init = 'it_inits_scope',
    call = 'it_calls_scope',
    __gc = 'it_frees_scope',
}, cdef)
Scope.type.prototype.defcdata = _ffi.get_define() -- HACK share pointer here


function Scope:__new()
    self.state = self.type:create(nil, _D._it_processes_, _D._it_scopes_)
    self.raw = self.state.lua
    if process.verbose then
        self:import(function () process.verbose = true end)
    end
    if process.debugmode then
        self:import(function () process.debug() end)
    end
    -- special case since object gets injected into process.context instead as global
    self:define('_it_scopes_', self.state, function ()
        process.context.scope = require('scope'):cast(_D._it_scopes_)
    end)
end
doc.info(Scope.__new, 'Scope:new', '(  )')

function Scope:__cast(pointer)
    self.state = self.type:ptr(pointer)
    self.raw = self.state.lua
end
doc.info(Scope.__cast, 'Scope:cast', '( pointer )')

function Scope:import(lua_function)
    self.state:import(lua_function)
    if self.state.err == nil then return end
    error(ffi.string(self.state.err))
    return self
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
    if self.state.err == nil then return end
    error(ffi.string(self.state.err))
    return self
end
doc.info(Scope.run, 'scope:run', '(  )')

return Scope
