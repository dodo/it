local ffi = require 'ffi'
local cface = require 'cface'
local Prototype = require 'prototype'
local Metatype = require 'metatype'

cface.decl("typedef size_t lua_State;")
cface.decl("typedef size_t uv_loop_t;")


local Scope = Prototype:fork()
Scope.type = Metatype:struct("it_states", {
    "int refc";
    "lua_State *lua";
    "uv_loop_t *loop";
    "const char *err";
    "bool free";
})

Scope.type:api("Scope", {'import', 'define'})
Scope.type:load('libapi.so', {
    ref = [[int it_refs(it_states* ref)]];
    unref = [[int it_unrefs(it_states* ref)]];
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
    -- special case since object gets injected into context instead as global
    self:define('_it_scopes_', self.state, function ()
        context.scope = require('scope'):new(_D._it_scopes_)
    end)
end

function Scope:import(lua_function)
    self.state:import(lua_function)
    if self.state.err == nil then return end
    error(ffi.string(self.state.err))
end

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

function Scope:run()
    self.state:call()
    if self.state.err == nil then return end
    error(ffi.string(self.state.err))
end

return Scope
