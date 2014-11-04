#include <stdio.h>

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

