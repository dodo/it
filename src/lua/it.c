#include <stdio.h>

#include <uv.h>

#include "it.h"
#include "luaI.h"

#include "lua/it.h"
#include "lua/ctx.h"
#include "lua/enc.h"
#include "lua/buffer.h"
#include "lua/frame.h"


int it_stdios_lua(lua_State* L) { // ()
    // stdio
    lua_pushnil(L);
    lua_setfield(L, -2, "stdnon");
    lua_pushlightuserdata(L, stdout);
    lua_setfield(L, -2, "stdout");
    lua_pushlightuserdata(L, stderr);
    lua_setfield(L, -2, "stderr");
    lua_pushlightuserdata(L, stdin);
    lua_setfield(L, -2, "stdin");
    return 0;
}

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

int it_versions_lua(lua_State* L) {
    lua_createtable(L, 0, 1);
    lua_pushfstring(L, "%s %s", IT_NAMES, IT_VERSIONS);
    lua_setfield(L, -2, "it");
    // * gcc
    lua_pushfstring(L, "gcc %d.%d.%d",
                        __GNUC__,
                        __GNUC_MINOR__,
                        __GNUC_PATCHLEVEL__);
    lua_setfield(L, -2, "gcc");
    // * libuv
    lua_pushfstring(L, "libuv %s", uv_version_string());
    lua_setfield(L, -2, "uv");
    // * luajit
    lua_pushfstring(L, "%s with %s",
                        LUAJIT_VERSION, LUA_RELEASE); // + _VERSION
    lua_setfield(L, -2, "lua");
    // * libschrödinger
    lua_pushfstring(L, "libschrödinger %d.%d.%d (Dirac %d.%d)",
                        SCHRO_VERSION_MAJOR,
                        SCHRO_VERSION_MINOR,
                        SCHRO_VERSION_MICRO,
                        SCHRO_ENCODER_VERSION_MAJOR,
                        SCHRO_ENCODER_VERSION_MINOR);
    lua_setfield(L, -2, "schroedinger");
    // * liboggz
    lua_pushfstring(L, "liboggz %s", PKG_OGGZ_VERSION);
    lua_setfield(L, -2, "ogg");
    // * liborc
    lua_pushfstring(L, "liborc %s", PKG_ORC_VERSION);
    lua_setfield(L, -2, "orc");
    return 1;
}

