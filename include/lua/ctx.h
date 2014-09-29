#ifndef LUA_CTX_H
#define LUA_CTX_H

#include <lua.h>

int it_imports_ctx_lua(lua_State* L);
int it_calls_ctx_lua(lua_State* L);
int it_kills_ctx_lua(lua_State* L);

#endif /* LUA_CTX_H */