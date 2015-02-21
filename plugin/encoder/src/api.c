#include <stdio.h>

#include <schroedinger/schro.h>
#include <schroedinger/schrodebug.h>

#include "it.h"
#include "api.h"
#include "luaI.h"

#include "frame.h"

#include "encoder.h"
static const luaL_Reg luaI_reg_encoder[] = {
    {"start", it_starts_encoder_lua},
    {"debug", it_debugs_encoder_lua},
    {"getsettings", it_gets_settings_encoder_lua},
    {"getformat", it_gets_format_encoder_lua},
    {"setformat", it_sets_format_encoder_lua},
    {NULL, NULL}
};



int register_api(lua_State* L, const char *name) {
    switch (name[0]) {
        case 'E'/*ncoder*/: luaI_newmetatable(L, name, luaI_reg_encoder); break; // FIXME
        default: luaI_error(L, "unknown metatable %s!", name); break;
    }
    return 0;
}

int api_version(lua_State* L) {
    lua_createtable(L, 0, 4);
    lua_pushliteral(L, "encoder plugin");
    lua_setfield(L, -2, "name");
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
