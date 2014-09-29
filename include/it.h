#ifndef IT_H
#define IT_H

#include <uv.h>
#include <lua.h>

#include "it-types.h"

int it_runs_ctx(it_states* ctx);

int it_gets_cwd_lua(lua_State* L);

int it_boots_lua(lua_State* L);
int it_forks_lua(lua_State* L);
int it_exits_lua(lua_State* L);

int it_imports_ctx_lua(lua_State* L);
int it_calls_ctx_lua(lua_State* L);
int it_kills_ctx_lua(lua_State* L);

#endif /* IT_H */