#include <stdio.h>

#include "it.h"
#include "uvI.h"
#include "luaI.h"

#include "api/it.h"



void it_sets_schro_debug_level(int level) {
//     schro_init(); // FIXME
//     schro_debug_set_level(level);
}

int it_stdios_lua(lua_State* L) { // (process)
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
    return 0;
}

int it_loads_lua(lua_State* L) { // (metatable_name, apifile_path)
    void (*load_metatable)(lua_State*, const char*);
    uv_lib_t* api = uvI_dlopen(lua_tostring(L, 2));
    uvI_dlsym(api, "register_api", &load_metatable);
    load_metatable(L, luaL_checkstring(L, 1));
    return 0;
}

int it_versions_lua(lua_State* L) { // (apifile_path)
    if (lua_isnil(L, 1)) return api_version(L);
    int (*plugin_version)(lua_State*);
    uv_lib_t* api = uvI_dlopen(lua_tostring(L, 1));
    uvI_dlsym(api, "api_version", &plugin_version);
    return plugin_version(L);
}
