local ffi = require 'ffi'
local cface = require 'cface'
local Prototype = require 'prototype'
local Metatype = require 'metatype'
local doc = require 'util.doc'

cface.decl("typedef size_t lua_State;")
cface.decl("typedef size_t uv_loop_t;")


local Scope = Prototype:fork()
Scope.type = Metatype:struct("it_states", {
    "int refc";
    "lua_State *lua";
    "uv_loop_t *loop";
    "const char *err";
    "bool safe";
    "bool free";
})

Scope.type:api("Scope", {'import', 'define'})
Scope.type:load('libapi.so', {
    ref = [[int it_refs(it_states* ref)]];
    unref = [[int it_unrefs(it_states* ref)]];
    collectgarbage = [[void it_collectsgarbage_scope(it_states* ctx)]];
    defcdata = [[void it_defines_cdata_scope(it_states* ctx, const char* name, void* cdata)]];
    init = [[void it_inits_scope(it_states* ctx, it_processes* process, it_states* state)]];
    call = [[void it_calls_scope(it_states* ctx)]];
    __gc = [[void it_frees_scope(it_states* ctx)]];
})


function Scope:init(pointer)
    if pointer then
        self.state = self.type:ptr(pointer)
        self.raw = self.state.lua
        return
    end
    self.state = self.type:create(nil, _D._it_processes_, _D._it_scopes_)
    self.raw = self.state.lua
    if process.debugmode then
        self:import(function () process.debug() end)
    end
    -- special case since object gets injected into context instead as global
    self:define('_it_scopes_', self.state, function ()
        context.scope = require('scope'):new(_D._it_scopes_)
    end)
end
doc.info(Scope.init, 'scope:init', '( [pointer] )')

function Scope:import(lua_function)
    self.state:import(lua_function)
    if self.state.err == nil then return end
    error(ffi.string(self.state.err))
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
end
doc.info(Scope.define, 'scope:define', '( name, data[, import] )')

function Scope:safe(safe)
    if safe == nil then safe = true end
    self.state.safe = not not safe
end
doc.info(Scope.safe, 'scope:safe', '( nil=true|true|false )')

function Scope:run()
    self.state:call()
    if self.state.err == nil then return end
    error(ffi.string(self.state.err))
end
doc.info(Scope.run, 'scope:run', '(  )')

return Scope
