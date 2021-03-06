#ifndef API_IT_H
#define API_IT_H

#include <lua.h>

#include "it.h"
#include "api.h"
#include "luaI.h"


extern int it_stdios_lua(lua_State* L);
extern int it_boots_lua(lua_State* L);
extern int it_loads_lua(lua_State* L);
extern int it_trims_string_lua(lua_State* L);
extern int it_holds_pointer_lua(lua_State* L);

extern int it_versions_lua(lua_State* L);


#endif /* API_IT_H */
