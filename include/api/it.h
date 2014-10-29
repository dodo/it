#ifndef API_IT_H
#define API_IT_H

#include <lua.h>

#include "it.h"
#include "api.h"
#include "luaI.h"


extern void it_sets_schro_debug_level(int level);

extern int it_stdios_lua(lua_State* L);
extern int it_boots_lua(lua_State* L);
extern int it_loads_lua(lua_State* L);

extern int it_versions_lua(lua_State* L);


#endif /* API_IT_H */