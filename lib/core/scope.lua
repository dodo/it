local ffi = require 'ffi'
local cface = require 'cface'
local Prototype = require 'prototype'
local Metatype = require 'metatype'

cface.decl("typedef size_t lua_State;")
cface.decl("typedef size_t uv_loop_t;")


local Scope = Prototype:fork()
Scope.type = Metatype:struct("it_states", {
    "lua_State *lua";
    "uv_loop_t *loop";
    "const char *err";
    "bool free";
})

Scope.type:api("Scope", {'import'})
Scope.type:load(_it.libdir .. "/api.so", {
    init = [[void it_inits_scope(it_states* ctx, it_processes* process, it_states* state)]];
    defboolean = [[void it_defines_boolean_scope(it_states* ctx,
                                               const char* name,
                                               int b)]];
    defcdata  = [[void it_defines_cdata_scope( it_states* ctx,
                                               const char* name,
                                               void* cdata)]];
    defnumber = [[void it_defines_number_scope(it_states* ctx,
                                               const char* name,
                                               double number)]];
    defstring = [[void it_defines_string_scope(it_states* ctx,
                                               const char* name,
                                               const char* string)]];
    call = [[void it_calls_scope(it_states* ctx)]];
    __gc = [[void it_frees_scope(it_states* ctx)]];
})


function Scope:init(pointer)
    if pointer then
        self.state = self.type:ptr(pointer)
        self.raw = self.state.lua
        return
    end
    self.state = self.type:create(nil, _D.process, _D.state)
    self.raw = self.state.lua
    -- special case since object gets injected into context instead as global
    self:define('scope', self.state, function ()
        context.scope = require('scope'):new(_D.scope)
    end)
end

function Scope:import(lua_function)
    return self.state:import(lua_function)
end

function Scope:define(name, data, import)
    if type(data) == 'string' then
        self.state:defstring(name, data)
    elseif type(data) == 'number' then
        self.state:defnumber(name, data)
    elseif type(data) == 'boolean' then
        self.state:defboolean(name, data)
    else
        self.state:defcdata(name, data)
    end
    if import then
        self:import(import)
    end
end

function Scope:call()
    return self.state:call()
end

return Scope
