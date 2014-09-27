#include <stdlib.h>
#include <stdio.h>
#include <ev.h>

#include <lua.h>
#include <lauxlib.h>


typedef struct {
    struct ev_loop *loop;
    ev_signal *sigint;
    lua_State *lua;
    int argc; char **argv;
    int exit_code;
} it_states;


static void sigint_cb(struct ev_loop *loop, ev_signal *w, int revents) {
    ev_break(loop, EVBREAK_ALL);
}

it_states* luaI_getstate(lua_State* L) {
    lua_getglobal(L, "__it_states");
    it_states* state = lua_touserdata(L, -1);
    lua_pop(L, 1);
    return state;
}

int it_exits_lua(lua_State* L) {
    it_states* state = luaI_getstate(L);
    int code = 0;
    if (lua_gettop(L))
        code = luaL_checkint(L, 1);
    state->exit_code = code;
    ev_break(state->loop, EVBREAK_ALL);
    return 0;
}

int it_boots_lua(lua_State* L) {
    it_states* state = luaI_getstate(L);
    // process.argv
    lua_createtable(L, state->argc, 0);
    int i; for (i = 0; i < state->argc; i++) {
        lua_pushstring(L, state->argv[i]);
        lua_rawseti(L, -2, i);
    }
    lua_setfield(L, -2, "argv");
    // process.exit
    lua_pushcfunction(L, it_exits_lua);
    lua_setfield(L, -2, "exit");
    return 0;
}

int main(int argc, char *argv[]) {
    it_states state;
    // default state values
    state.argc = argc;
    state.argv = argv;
    state.exit_code = -1;
    state.loop = EV_DEFAULT;
    ev_set_userdata(state.loop, &state);
    // init signals
    ev_signal sigint_signal;
    state.sigint = &sigint_signal;
    // start signal watchers
    ev_signal_init(state.sigint, sigint_cb, SIGINT);
    ev_signal_start(state.loop, state.sigint);

    // create lua state
    state.lua = luaL_newstate();
    if (!state.lua) {
        fprintf(stderr, "failed to allocate lua state!\n");
        exit(1);
    }
    // load lua libs
    luaL_openlibs(state.lua);
    // remember global state
    lua_pushlightuserdata(state.lua, &state);
    lua_setglobal(state.lua, "__it_states");
    // c entry point after first lua call
    lua_pushcfunction(state.lua, &it_boots_lua);
    lua_setglobal(state.lua, "__it_boots");
    // load lua kernel
    if (luaL_loadfile(state.lua, "lib/initrd.lua")) {
        fprintf(stderr, "failed to load lua kernel: %s\n", lua_tostring(state.lua, -1));
        exit(1);
    }
    // boot lua
    lua_call(state.lua, 0, 0);
    // run forest run!
    if (state.exit_code == -1)
        ev_run(state.loop, 0);
    // shutdown
    lua_close(state.lua);
    return state.exit_code;
}
