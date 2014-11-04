#include <stdio.h>

#include "it.h"
#include "api.h"
#include "luaI.h"

#include "frame.h"


#include "encoder.h"
static const luaL_Reg luaI_reg_encoder[] = {
    {"start", it_starts_encoder_lua},
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
