
#include "it.h"
#include "luaI.h"

#include "lua/window.h"
#include "lua/ctx.h"

static void it_frees_window(it_windows* win) {
    if (!win) return;
    sdlI_ref(-1);
    if (win->window) {
        SDL_DestroyWindow(win->window);
        win->window = NULL;
    }
    if (win->renderer) {
        SDL_DestroyRenderer(win->renderer);
        win->renderer = NULL;
    }
}

int sdlI_ref(int c) {
    static int count = 0;
    if (!count) {
        if (SDL_Init(SDL_INIT_EVERYTHING))
            sdlI_error("SDL_Init: failed to initialize SDL (%s)");
    }
    count += c;
    if (!count) SDL_Quit();
    return count;
}

int it_new_window_lua(lua_State* L) { // ((optional) win_pointer)
    if (lua_gettop(L) == 1 && lua_islightuserdata(L, 1)) {
        lua_newtable(L);
    } else {
        it_windows* win = lua_newuserdata(L, sizeof(it_windows));
        memset(win, 0, sizeof(it_windows));
    }
    luaI_setmetatable(L, "Window");
    return 1;
}

int it_inits_window_lua(lua_State* L) { // (win_userdata, ctx_userdata)
    it_windows* win = luaL_checkudata(L, 1, "Window");
    it_states*  ctx = luaL_checkudata(L, 2, "Context");
    win->ctx = ctx;
    return 0;
}

int it_creates_window_lua(lua_State* L) { // (win_userdata)
    it_windows* win = luaL_checkudata(L, 1, "Window");
    sdlI_ref(1);
    if (win->window) it_frees_window(win);
    win->window = SDL_CreateWindow(
        luaL_checkstring(L, 2), // title
        lua_isnil(L, 3) ? SDL_WINDOWPOS_UNDEFINED : luaL_checkint(L, 3), // x
        lua_isnil(L, 4) ? SDL_WINDOWPOS_UNDEFINED : luaL_checkint(L, 4),  // y
        luaL_checkint(L, 5),    // width
        luaL_checkint(L, 6),    // height
        SDL_WINDOW_SHOWN // flags
    );
    if (!win->window)
        sdlI_lua_error(L, "SDL_CreateWindow: failed to create window (%s)");
    win->renderer = SDL_CreateRenderer(win->window, -1, SDL_RENDERER_ACCELERATED);
    if (!win->renderer)
        sdlI_lua_error(L, "SDL_CreateRenderer: failed to create renderer (%s)");
    SDL_SetRenderDrawColor(win->renderer, 255, 0, 0, 255);
    SDL_RenderClear(win->renderer);
    SDL_RenderPresent(win->renderer);
    return 0;
}

int it_kills_window_lua(lua_State* L) { // (win_userdata)
    it_frees_window(luaL_checkudata(L, 1, "Window"));
    return 0;
}
