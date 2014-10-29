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
    "bool free";
})

Scope.type:api("Scope", {'import'})
Scope.type:load(_it.libdir .. "/api.so", {
    init = [[void it_inits_scope(it_states* ctx, it_processes* process, it_states* state)]];
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
        return
    end
    self.state = self.type:create(nil, _it.process, _it.state)
end

function Scope:import(lua_function)
    return self.state:import(lua_function)
end

function Scope:define(name, data, import)
    if type(data) == 'string' then
        self.state:defstring(name, data)
    elseif type(data) == 'number' then
        self.state:defnumber(name, data)
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
