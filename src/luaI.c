#define __USE_GNU
#define _GNU_SOURCE
#include <dlfcn.h>

#include "uvI.h"
#include "luaI.h"

#include "it.h"
#include "api.h"
#include "core-types.h"
#include "api/process.h"


void luaI_newmetatable(lua_State* L, const char *name, const luaL_Reg *l) {
    if (luaL_newmetatable(L, name)) {
        luaL_newlib(L, l);
        lua_setfield(L, -2, "__index");
        for (; l->name; l++) {
            // __* method are metatable specific
            if (l->name[0] == '_' && l->name[1] == '_') {
                lua_pushcfunction(L, l->func);
                lua_setfield(L, -2, l->name);
            }
        }
    }
}

static int buf_writer(lua_State* L, const void* b, size_t n, void* B) {
  (void)L;
  luaL_addlstring((luaL_Buffer*) B, (const char *)b, n);
  return 0;
}
int luaI_copyfunction(lua_State* L, lua_State* src) {
    char const* name = NULL; // TODO
    size_t sz;
    luaL_Buffer b;
    luaL_buffinit(src, &b);
    if (lua_dump(src, buf_writer, &b))
        luaI_error(src, "function dump failed");
    luaL_pushresult(&b);
    char const* s = lua_tolstring(src, -1, &sz);
    if (luaL_loadbuffer(L, s, sz, name)) {
        return lua_error(L);
    }
    // disable JIT for this function because it's allready bytecode
    luaJIT_setmode(L, -1, LUAJIT_MODE_FUNC | LUAJIT_MODE_OFF);
    lua_pop(src, 2); // dumped string + function
    return 0;
}

luaI_function* luaI_tofunction(lua_State* L, int index) {
    luaI_function* func = (luaI_function*) calloc(1, sizeof(luaI_function));
    if (!func) return NULL;
    int stack = 0;
    if (index != -1) {
        lua_pushvalue(L, index);
        stack++;
    }
    { // start dumping function …
        size_t sz;
        luaL_Buffer b;
        luaL_buffinit(L, &b);
        if (lua_dump(L, buf_writer, &b)) {
            luaL_error(L, "internal error: function dump failed");
            free(func);
            return NULL;
        }
        luaL_pushresult(&b);
        func->name = NULL; // TODO
        func->dump = lua_tolstring(L, -1, &sz);
        func->size = sz;
    }
    lua_pop(L, stack); // dumped string + maybe function
    return func;
}

int luaI_pushfunction(lua_State* L, luaI_function* func) {
    if (!func) return 0;
    if (luaL_loadbuffer(L, func->dump, func->size, func->name)) {
        return lua_error(L);
    }
    // disable JIT for this function because it's allready bytecode
    luaJIT_setmode(L, -1, LUAJIT_MODE_FUNC | LUAJIT_MODE_OFF);
    // hopefully i remember to set all references to NULL after this call
    free(func);
    return 1;
}

int luaI_dofile(lua_State* L, const char *filename) {
    if (luaL_dofile(L, filename)) {
        return lua_error(L);
    }
    return 0;
}

void* luaI_checklightuserdata(lua_State* L, int i, const char *metatable) {
    return (lua_islightuserdata(L, i)) ?
         lua_touserdata(L, i) :
        luaL_checkudata(L, i, metatable);
}

it_processes* luaI_getprocess(lua_State* L) {
    luaI_getdefine(L, "_it_processes_");
    it_processes* process = lua_touserdata(L, -1);
    lua_pop(L, 1);
    return process;
}

it_states* luaI_getstate(lua_State* L) {
    luaI_getdefine(L, "_it_scopes_");
    it_states* state = lua_touserdata(L, -1);
    lua_pop(L, 1);
    return state;
}

int luaI_setstate(lua_State* L, it_states* ctx) {
    lua_pushlightuserdata(L, ctx);
    luaI_setdefine(L, "_it_scopes_");
    luaL_loadstring(L,
        // concat arguments to get one string
        "_it.execcmd = ... "
        // remove executable name
        "_it.execpath = _it.execcmd:match('^(.*/)[^/]+$') "
        // build some static paths
        "_it.apifile = 'api' "
        "_it.plugindir = _it.execpath .. 'plugin/' "
        "_it.libdir = _it.execpath .. 'lib/' "
        // load package patches
        "dofile(_it.libdir .. 'package.lua')"
    );
    { // add exec_path as only argument
        size_t size =  2*PATH_MAX;
        char exec_path[2*PATH_MAX];
        uv_exepath(exec_path, &size);
        lua_pushlstring(L, exec_path, size);
    }
    lua_call(L, 1, 0);
    return 0;
}

const char* luaI_getlibpath(lua_State* L, const char* filename) {
    luaI_getglobalfield(L, "_it", "libdir");
    lua_pushstring(L, filename);
    lua_concat(L, 2);
    filename = lua_tostring(L, -1); lua_pop(L, 1);
    return filename;
}

void luaI_createdefinetable(lua_State* L) {
    // creates table containing all variables that get defined via C
    lua_newtable(L);
    lua_setglobal(L, "_D");
    // expose them as globals
    lua_getglobal(L, "_G");
    lua_createtable(L, 0, 1);
    lua_getglobal(L, "_D");
    lua_setfield(L, -2, "__index");
    lua_setmetatable(L, -2);
    // store reference to _D in package.loaded
    luaI_getglobalfield(L, "package", "loaded");
    lua_getglobal(L, "_D");
    lua_setfield(L, -2, "_D");
    lua_pop(L, 2);
}

void luaI_getdefine(lua_State* L, const char* key) {
    luaI_getglobalfield(L, "_D", key);
}

void luaI_setdefine(lua_State* L, const char* key) {
    luaI_setglobalfield(L, "_D", key);
}

luaI_value* luaI_getvalue(lua_State* L, int i) {
    luaI_value* value = (luaI_value*) calloc(1, sizeof(luaI_value));
    if (!value) return NULL;
    switch (lua_type(L, i)) {
        case LUA_TNUMBER:
            value->type = LUAI_TYPE_NUMBER;
            value->v.number = lua_tonumber(L, i);
            break;
        case LUA_TBOOLEAN:
            value->type = LUAI_TYPE_BOOLEAN;
            value->v.boolean = lua_toboolean(L, i);
            break;
        case LUA_TSTRING:
            value->type = LUAI_TYPE_STRING;
            value->v.string = lua_tostring(L, i);
            break;
        case LUA_TUSERDATA:
        case LUA_TLIGHTUSERDATA:
            value->type = LUAI_TYPE_CDATA;
            value->v.cdata = lua_touserdata(L, i);
            break;
        case LUA_TFUNCTION:
            value->type = LUAI_TYPE_FUNCTION;
            value->v.function = luaI_tofunction(L, i);
            break;
        case LUA_TNIL:
        default:
            value->type = LUAI_TYPE_NIL;
            break;
    }
    return value;
}

void luaI_pushvalue(lua_State* L, luaI_value* value) {
    if (!value) return;
    switch (value->type) {
        case LUAI_TYPE_NUMBER:
            lua_pushnumber(L, value->v.number);
            break;
        case LUAI_TYPE_BOOLEAN:
            lua_pushboolean(L, value->v.boolean);
            break;
        case LUAI_TYPE_STRING:
            lua_pushstring(L, value->v.string);
            break;
        case LUAI_TYPE_CDATA:
            lua_pushlightuserdata(L, value->v.cdata);
            break;
        case LUA_TFUNCTION:
            luaI_pushfunction(L, value->v.function);
            value->v.function = NULL;
        case LUAI_TYPE_NIL:
        default:
            lua_pushnil(L);
            break;
    }
}

int luaI_newstate(it_states* ctx) {
    if (!ctx || ctx->lua) return 1;
    // create lua state
    lua_State* L = luaL_newstate();
    if (!L) {
        it_prints_error("failed to allocate lua state!");
        return 1;
    }
    ctx->lua = L;
    // enable JIT
    luaJIT_setmode(L, 0, LUAJIT_MODE_ENGINE | LUAJIT_MODE_ON);
    // load lua libs
    lua_gc(L, LUA_GCSTOP, 0);  // stop collector during initialization
    luaL_openlibs(L);
    luaI_createdefinetable(L);
    register_api(ctx->lua, "_it"); // api.c main

    if (luaI_setstate(L, ctx)) {
        lua_gc(L, LUA_GCRESTART, -1);
        it_prints_error("failed to initialize lua state!");
        return 1;
    }
    luaI_init_errorhandling(L);
    lua_gc(L, LUA_GCRESTART, -1);
    return 0;
}

int luaI_createstate(it_processes* process) {
    if (!process) return 0; // fail
    it_creates_process(process);
    it_states* ctx = process->ctx;
    if (luaI_newstate(ctx)) {
        return 0; // fail
    }
    lua_pushlightuserdata(ctx->lua, process);
    luaI_setdefine(ctx->lua, "_it_processes_");
    // initrd returns a function to be called when everything is initialized
    luaI_dofile(ctx->lua, luaI_getlibpath(ctx->lua, "initrd.lua"));
    it_inits_process(process);
    return 1; // success
}

int luaI_closestate(it_processes* process) {
    if (!process) return 0; // fail
    it_closes_process(process);
    return 1; // success
}

int luaI_pcall(lua_State* L, int nargs, int nresults, int safe) {
    if (luaI_xpcall(L, nargs, nresults, safe)) {
        return lua_error(L);
    }
    return 0; // success
}

int luaI_pcall_in(it_states* ctx, int nargs, int nresults) {
    if (!ctx || ctx->err) return 1;
    if (!ctx->lua) {
        ctx->err = "internal error: luaI_pcall_in missing lua state!";
        return 1;
    }
    if (luaI_xpcall(ctx->lua, nargs, nresults, ctx->safe)) {
        if (lua_isstring(ctx->lua, -1)) {
            const char* err = lua_tostring(ctx->lua, -1);
            lua_pop(ctx->lua, 1);
            lua_pushfstring(ctx->lua, "error in scope '%s': %s", ctx->name,err);
        }
        ctx->err = lua_tostring(ctx->lua, -1);
        lua_pop(ctx->lua, 1);
        return 1;
    }
    return 0;
}

int luaI_emit(lua_State* L, const char* event) {
    lua_getfield(L, -1, "emit");
    if (lua_isnil(L, -1)) {
        lua_pop(L, 2);
        return 1;
    }
    lua_pushvalue(L, -2);
    lua_remove(L, -3);
    lua_pushstring(L, event);
    return 0;
}

int luaI_localemit(lua_State* L, const char* field, const char* event) {
    luaI_getlocalfield(L, field);
    if (luaI_emit(L, event))
        luaI_error(L,
            "local field %s does not has an emit method for event %s.",
            field, event);
    return 0;
}

int luaI_globalemit(lua_State* L, const char* global, const char* event) {
    luaI_getglobalfield(L, global, "emit");
    if (lua_isnil(L, -1)) {
        lua_pop(L, 1);
        luaI_error(L,
            "global %s does not has an emit method for event %s.",
            global, event);
    }
    lua_getglobal(L, global);
    lua_pushstring(L, event);
    return 0;
}

int luaI_gc(lua_State* L) {
    if (lua_gc(L, LUA_GCCOLLECT, 0))
        luaI_error(L, "lua_gc failed");
    return 0;
}

void luaI_close(lua_State* L, int code) {
    lua_getfield(L, -1, "emit");
    lua_pushvalue(L, -2);
    lua_pushliteral(L, "exit");
    if (code > -1) lua_pushinteger(L, code);
    luaI_pcall(L, (code == -1) ? 2 : 3, 0, 2/*super safe*/);
    // we are done now:
    lua_close(L);
}

const char* uvI_debug_stacktrace(uvI_thread_t* thread, lua_State* L) {
    lua_pushliteral(L, "DEBUG");
    uvI_thread_stacktrace(thread);
    luaI_stacktrace(L);
    const char* st = lua_tostring(L, -1);
    lua_pop(L, 1);
    return st;
}
