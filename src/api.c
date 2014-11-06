#include <stdio.h>

#include <uv.h>
#include <SDL.h>

#include "it.h"
#include "luaI.h"

#include "api.h"
#include "core-api.h"


#include "api/it.h"
static const luaL_Reg luaI_reg_it[] = {
    {"boots", it_boots_lua},
    {"loads", it_loads_lua},
    {"versions", it_versions_lua},
    {NULL, NULL}
};

#include "api/scope.h"
static const luaL_Reg luaI_reg_scope[] = {
    {"import", it_imports_scope_lua},
    {NULL, NULL}
};


int register_api(lua_State* L, const char *name) {
    switch (name[0]) {
        case '_'/*it*/:     luaI_newlib(L, name, luaI_reg_it);            break;
        case 'S'/*cope*/:   luaI_newmetatable(L, name, luaI_reg_scope);   break;
        default: luaI_error(L, "unknown metatable %s!", name); break;
    }
    return 0;
}

int api_version(lua_State* L) {
    lua_createtable(L, 0, 5);
    lua_pushfstring(L, "[%s] %s", IT_VERSIONS, IT_NAMES);
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
    // * libsdl2
    SDL_version compiled;
    SDL_version linked;

    SDL_VERSION(&compiled);
    SDL_GetVersion(&linked);
    lua_pushfstring(L, "libsdl2 %d.%d.%d (linked against %d.%d.%d)",
                        compiled.major, compiled.minor, compiled.patch,
                        linked.major, linked.minor, linked.patch);
    lua_setfield(L, -2, "sdl");
    return 1;
}
