#include <stdio.h>

#include "it.h"
#include "api.h"
#include "luaI.h"

#include "audio.h"



int register_api(lua_State* L, const char *name) {
    switch (name[0]) {
        default: luaI_error(L, "unknown metatable %s!", name); break;
    }
    return 0;
}

int api_version(lua_State* L) {
    lua_createtable(L, 0, 4);
    lua_pushstring(L, "audio plugin");
    lua_setfield(L, -2, "name");
    // * libopenal
    lua_pushfstring(L, "libopenal %s", PKG_OPENAL_VERSION);
    lua_setfield(L, -2, "openal");
    return 1;
}
