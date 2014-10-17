#include <stdio.h>

#include <uv.h>

#include "it.h"
#include "luaI.h"

#include "lua/it.h"
#include "lua/ctx.h"
#include "lua/enc.h"
#include "lua/buffer.h"
#include "lua/frame.h"


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
    return it_new_ctx_lua(L);
}

int it_encodes_lua(lua_State* L) { // ((optional) enc_pointer)
    return it_new_enc_lua(L);
}

int it_buffers_lua(lua_State* L) { // ()
    return it_new_buffer_lua(L);
}

int it_frames_lua(lua_State* L)  {// (width, height)
    return it_new_frame_lua(L);
}

