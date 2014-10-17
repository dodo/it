#include <stdio.h>

#include <uv.h>

#define SCHRO_ENABLE_UNSTABLE_API

#include <schroedinger/schro.h>

#include "it.h"
#include "luaI.h"

#include "lua/it.h"


int it_boots_lua(lua_State* L) { // (process)
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
    lua_pushnil(L);
    lua_setfield(L, -2, "stdnon");
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

int it_loads_lua(lua_State* L) { // (metatable_name)
    return luaI_loadmetatable(L, 1);
}

int it_forks_lua(lua_State* L) { // ()
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

int it_encodes_lua(lua_State* L) { // ((optional) enc_pointer)
    if (lua_gettop(L) == 1 && lua_islightuserdata(L, 1)) {
        lua_newtable(L);
    } else {
        it_encodes* enc = lua_newuserdata(L, sizeof(it_encodes));
        enc->encoder = NULL;
        enc->thread = NULL;
    }
    luaI_setmetatable(L, "Encoder");
    return 1;
}

int it_buffers_lua(lua_State* L) { // ()
    it_buffers* buf = lua_newuserdata(L, sizeof(it_buffers));
    buf->free = FALSE;
    buf->buffer = NULL;
    luaI_setmetatable(L, "Buffer");
    return 1;
}

int it_frames_lua(lua_State* L)  {// (width, height)
    int w = luaL_checkint(L, 1);
    int h = luaL_checkint(L, 2);
    int size = ROUND_UP_4(w) * ROUND_UP_2(h);
    size += (ROUND_UP_8(w)/2) * (ROUND_UP_2(h)/2);
    size += (ROUND_UP_8(w)/2) * (ROUND_UP_2(h)/2);
    it_frames* fr = lua_newuserdata(L, sizeof(it_frames));
    fr->ctx = luaI_getstate(L);
    fr->frame = NULL;
    fr->size = size;
    fr->width = w;
    fr->height = h;
    luaI_setmetatable(L, "Frame");
    return 1;
}

