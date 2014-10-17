#ifndef LUA_CTX_H
#define LUA_CTX_H

#include <lua.h>

void it_frees_ctx(it_states* ctx);
int it_new_ctx_lua(lua_State* L);
int it_imports_ctx_lua(lua_State* L);
int it_calls_ctx_lua(lua_State* L);
int it_kills_ctx_lua(lua_State* L);

#endif /* LUA_CTX_H */