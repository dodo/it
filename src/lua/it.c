#include <stdio.h>

#include "lua/it.h"

#include "it.h"
#include "luaI.h"


int it_boots_lua(lua_State* L) {
    it_processes* process = luaI_getprocess(L);
    // process.argv
    lua_createtable(L, process->argc, 0);
    int i; for (i = 0; i < process->argc; i++) {
        lua_pushstring(L, process->argv[i]);
        lua_rawseti(L, -2, i);
    }
    lua_setfield(L, -2, "argv");
    // process.pid
    lua_pushinteger(L, getpid());
    lua_setfield(L, -2, "pid");
    // stdio
    lua_pushlightuserdata(L, stdout);
    lua_setfield(L, -2, "stdout");
    lua_pushlightuserdata(L, stderr);
    lua_setfield(L, -2, "stderr");
    lua_pushlightuserdata(L, stdin);
    lua_setfield(L, -2, "stdin");
    // cfunction metatable
    lua_newtable(L);
    luaI_setmetatable(L, "Process");
    return 1;
}

int it_loads_lua(lua_State* L) {
    return luaI_loadmetatable(L, 1);
}

int it_forks_lua(lua_State* L) {
    it_states* state = luaI_getstate(L);
    it_states* ctx = lua_newuserdata(L, sizeof(it_states));
    ctx->loop = state->loop;
    if (luaI_newstate(ctx)) {
        lua_pushnil(L);
        return 1;
    }
    luaI_setmetatable(L, "Context");
    luaI_dofile(ctx->lua, "lib/context.lua");
    return 1;
}

int it_encodes_lua(lua_State* L) {
    lua_newuserdata(L, sizeof(it_encodes));
    luaI_setmetatable(L, "Encoder");
    return 1;
}

int it_buffers_lua(lua_State* L) {
    it_buffers* buf = lua_newuserdata(L, sizeof(it_buffers));
    buf->free = FALSE;
    buf->buffer = NULL;
    luaI_setmetatable(L, "Buffer");
    return 1;
}

