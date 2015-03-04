#ifndef API_SCOPE_H
#define API_SCOPE_H

#include <lua.h>

#include "it.h"
#include "api.h"
#include "luaI.h"

#include "api/scope.h"
#include "api/process.h"

extern it_states* it_allocs_scope();

extern int it_imports_scope_lua(lua_State* L);
extern int it_defines_scope_lua(lua_State* L);

extern void it_inits_scope(it_states* ctx, it_processes* process);
extern void it_defines_cdata_scope(  it_states* ctx, const char* name, void* cdata);
extern void it_defines_number_scope( it_states* ctx, const char* name, double number);
extern void it_defines_string_scope( it_states* ctx, const char* name, const char* string);
extern void it_defines_boolean_scope(it_states* ctx, const char* name, int b);
extern void it_calls_scope(it_states* ctx);
extern void it_collectsgarbage_scope(it_states* ctx);
extern void it_closes_scope(it_states* ctx);
extern void it_frees_scope(it_states* ctx);


#endif /* API_SCOPE_H */
