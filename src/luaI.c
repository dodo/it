#include "luaI.h"

#include "it.h"


#include "lua/it.h"
static const luaL_Reg luaI_reg_it[] = {
    {"boots", it_boots_lua},
    {"stdios", it_stdios_lua},
    {"loads", it_loads_lua},
    {"forks", it_forks_lua},
    {"encodes", it_encodes_lua},
    {"buffers", it_buffers_lua},
    {"frames", it_frames_lua},
    {"versions", it_versions_lua},
    {NULL, NULL}
};

#include "lua/process.h"
static const luaL_Reg luaI_reg_process[] = {
    {"exit", it_exits_process_lua},
    {"cwd",  it_gets_cwd_process_lua},
    {NULL, NULL}
};

#include "lua/buffer.h"
static const luaL_Reg luaI_reg_buffer[] = {
    {"malloc", it_mallocs_buffer_lua},
    {"memcpy", it_memcpies_buffer_lua},
    {"user", it_uses_userdata_buffer_lua},
    {"__gc", it_kills_buffer_lua},
    {NULL, NULL}
};


#include "lua/ctx.h"
static const luaL_Reg luaI_reg_ctx[] = {
    {"import", it_imports_ctx_lua},
    {"call", it_calls_ctx_lua},
    {"__gc", it_kills_ctx_lua},
    {NULL, NULL}
};

#include "lua/enc.h"
static const luaL_Reg luaI_reg_enc[] = {
    {"create", it_creates_enc_lua},
    {"start", it_starts_enc_lua},
    {"push", it_pushes_frame_enc_lua},
    {"getformat", it_gets_format_enc_lua},
    {"setformat", it_sets_format_enc_lua},
    {"setdebug", it_sets_debug_enc_lua},
    {"__gc", it_kills_enc_lua},
    {NULL, NULL}
};

#include "lua/frame.h"
static const luaL_Reg luaI_reg_frame[] = {
    {"create", it_creates_frame_lua},
    {"convert", it_converts_frame_lua},
    {"getdata", it_gets_data_frame_lua},
    {"reverse_order", it_reverses_order_frame_lua},
    {"__gc", it_kills_frame_lua},
    {NULL, NULL}
};


int luaI_loadmetatable(lua_State* L, int i) {
    const char *name = lua_tostring(L, i);
    switch (name[0]) {
        case '_'/*it*/:     luaI_newlib(L, name, luaI_reg_it); break;
        case 'B'/*uffer*/:  luaI_newmetatable(L, name, luaI_reg_buffer); break;
        case 'C'/*ontext*/: luaI_newmetatable(L, name, luaI_reg_ctx); break;
        case 'E'/*ncoder*/: luaI_newmetatable(L, name, luaI_reg_enc); break;
        case 'F'/*rame*/:   luaI_newmetatable(L, name, luaI_reg_frame); break;
        case 'P'/*rocess*/: luaI_newmetatable(L, name, luaI_reg_process); break;
        default: luaI_error(L, "unknown metatable %s!", name); break;
    }
    lua_pop(L, 1); // dont need metatable right now
    return 0;
}

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
    char const* name = NULL;
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
    lua_pop(src, 2); // dumped string + function
    return 0;
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
    luaI_getglobalfield(L, "_it", "process");
    it_processes* process = lua_touserdata(L, -1);
    lua_pop(L, 1);
    return process;
}

it_states* luaI_getstate(lua_State* L) {
    luaI_getglobalfield(L, "_it", "state");
    it_states* state = lua_touserdata(L, -1);
    lua_pop(L, 1);
    return state;
}

int luaI_setstate(lua_State* L, it_states* ctx) {
    size_t size = 2*PATH_MAX;
    char exec_path[2*PATH_MAX];
    if (uv_exepath(exec_path, &size))
        uvI_lua_error(L, ctx->loop, "%s uv_exepath: %s");
    lua_pushlightuserdata(L, ctx);
    luaI_setglobalfield(L, "_it", "state");
    luaL_loadstring(L,
        // concat arguments to get one string
        "_it.execpath = table.concat({...}, '') "
        // remove executable name and append libdir
        "_it.libdir = _it.execpath:match('^(.*)/[^/]+$') .. '/lib/' "
        // prepend to lua search paths
        "package.path = _it.libdir .. 'core/?.lua;' .. package.path");
    lua_pushlstring(L, exec_path, size);
    lua_call(L, 1, 0);
    return 0;
}

static int at_panic(lua_State* L) {
    luaI_getglobalfield(L, "process", "emit");
    lua_getglobal(L, "process");
    lua_pushstring(L, "panic");
    lua_pushvalue(L, -4);
    luaI_pcall(L, 3, 0);
    lua_pop(L, 1);
    fprintf(stderr, "PANIC@%s\n", lua_tostring(L, -1));
    return 0;
}

int luaI_newstate(it_states* ctx) {
    // create lua state
    lua_State* L = luaL_newstate();
    if (!L) {
        it_prints_error("failed to allocate lua state!");
        return 1;
    }
    ctx->free = TRUE;
    ctx->lua = L;
    lua_atpanic(L, at_panic);
    // enable JIT
    luaJIT_setmode(L, 0, LUAJIT_MODE_ENGINE | LUAJIT_MODE_ON);
    // load lua libs
    lua_gc(L, LUA_GCSTOP, 0);  // stop collector during initialization
    luaL_openlibs(L);
    luaI_newlib(ctx->lua, "_it", luaI_reg_it);
    if (luaI_setstate(L, ctx)) {
        lua_gc(L, LUA_GCRESTART, -1);
        it_prints_error("failed to initialize lua state!");
        return 1;
    }
    lua_gc(L, LUA_GCRESTART, -1);
    return 0;
}

int luaI_createstate(it_processes* process) {
    it_states* ctx = process->ctx;
    if (luaI_newstate(ctx)) {
        return 1;
    }
    lua_pushlightuserdata(ctx->lua, process);
    luaI_setglobalfield(ctx->lua, "_it", "process");
    luaI_dofile(ctx->lua, "lib/initrd.lua");
    return 0;
}

void luaI_close(lua_State* L, const char *global, int code) {
    lua_getglobal(L, global);
    lua_getfield(L, -1, "emit");
    lua_pushvalue(L, -2);
    lua_pushstring(L, "exit");
    if (code > -1) lua_pushinteger(L, code);
    luaI_pcall(L, (code == -1) ? 2 : 3, 0);
    // we are done now:
    lua_close(L);
}
