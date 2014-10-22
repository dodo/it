
#include "it.h"
#include "luaI.h"

#include "lua/window.h"
#include "lua/thread.h"

static void it_frees_window(it_windows* win) {
    if (!win) return;
    if (win->window) {
        SDL_DestroyWindow(win->window);
        win->window = NULL;
    }
    if (win->renderer) {
        SDL_DestroyRenderer(win->renderer);
        win->renderer = NULL;
    }
    sdlI_ref(-1);
}

int sdlI_ref(int c) {
    static int count = 0;
    if (!count) {
        if (SDL_Init(SDL_INIT_EVERYTHING))
            sdlI_error("SDL_Init: failed to initialize SDL (%s)");
    }
    count += c;
    if (count < 0) count = 0;
    if (!count) SDL_Quit();
    return count;
}

static void sdlI_create(void* priv) {
    it_windows* win = (it_windows*) priv;
    // inject window handle into lua context …
    lua_pushlightuserdata(win->thread->ctx->lua, win);
    lua_setglobal(win->thread->ctx->lua, "window");
}

static void sdlI_free(void* priv) {
    it_frees_window((it_windows*) priv);
}

static void sdlI_idle(void* priv) {
    it_windows* win = (it_windows*) priv;
    SDL_Event event;
    while (SDL_PollEvent(&event)) {

        switch (event.type) {

            default:
                break;
        }
        if (event.type == SDL_QUIT || win->thread->closed) break;
    }
    if (event.type == SDL_QUIT || win->thread->closed) {
        luaI_getglobalfield(win->thread->ctx->lua, "window", "emit");
        lua_getglobal(win->thread->ctx->lua, "window"); // self
        lua_pushstring(win->thread->ctx->lua, "close");
        luaI_pcall(win->thread->ctx->lua, 2, 0);
        win->thread->free = NULL;
        sdlI_ref(1); // prevent SDL_Quit
        sdlI_free(priv);
        uv_close((uv_handle_t*) win->thread->idle, NULL);
        uv_stop(win->thread->ctx->loop);
        return;
    }
    // call lua …
    luaI_getglobalfield(win->thread->ctx->lua, "context", "emit");
    lua_getglobal(win->thread->ctx->lua, "context"); // self
    lua_pushstring(win->thread->ctx->lua, "need render");
    luaI_pcall(win->thread->ctx->lua, 2, 0);
    // free all unused data and other stuff
    if (lua_gc(win->thread->ctx->lua, LUA_GCCOLLECT, 0))
        luaL_error(win->thread->ctx->lua, "internal error: lua_gc failed");
}

int it_new_window_lua(lua_State* L) { // (window, (optional) win_pointer)
    if (lua_gettop(L) == 2 && lua_islightuserdata(L, 2)) {
        it_windows* win = lua_touserdata(L, 2);
        lua_newtable(L);
        int w, h;
        SDL_GetWindowSize(win->window, &w, &h);
        lua_pushinteger(L, w);
        lua_setfield(L, 1, "width");
        lua_pushinteger(L, h);
        lua_setfield(L, 1, "height");
    } else {
        it_windows* win = lua_newuserdata(L, sizeof(it_windows));
        memset(win, 0, sizeof(it_windows));
    }
    luaI_setmetatable(L, "Window");
    return 1;
}

int it_inits_window_lua(lua_State* L) { // (win_userdata, ctx_userdata)
    it_windows* win    = luaL_checkudata(L, 1, "Window");
    it_threads* thread = luaL_checkudata(L, 2, "Thread");
    win->thread = thread;
    thread->priv = win;
    thread->init = sdlI_create;
    thread->callback = sdlI_idle;
    thread->free = sdlI_free;
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

int it_renders_window_lua(lua_State* L) { // (win_userdata, width, height, void*_data, stride) or (win_userdata, width, height, function)
    it_windows* win = luaI_checklightuserdata(L, 1, "Window");
    if (!win->window) return 0;
    SDL_Surface* screen = SDL_GetWindowSurface(win->window);
    if (!screen)
        sdlI_lua_error(L,"SDL_GetWindowSurface: failed to get window surface (%s)");
    SDL_Surface* surface = NULL;
    if (lua_isuserdata(L, 4)) {
        surface = SDL_CreateRGBSurfaceFrom(
            lua_touserdata(L, 4), // data
            luaL_checkint(L,  2), // width
            luaL_checkint(L,  3), // height
            32,                   // depth
            luaL_checkint(L,  5), // stride
            0x00ff0000,           // Rmask
            0x0000ff00,           // Gmask
            0x000000ff,           // Bmask
            0xff000000            // Amask
        );
    } else {
        surface = SDL_CreateRGBSurface(
            0,                    // flags
            luaL_checkint(L,  2), // width
            luaL_checkint(L,  3), // height
            32,                   // depth
            0x00ff0000,           // Rmask
            0x0000ff00,           // Gmask
            0x000000ff,           // Bmask
            0xff000000            // Amask
        );
        if (lua_isfunction(L, 4)) {
            lua_pushvalue(L, 4);
            lua_pushlightuserdata(L, surface->pixels);
            lua_pushinteger(L, 4 * luaL_checkint(L,  2) * luaL_checkint(L,  3)); // length
            luaI_pcall(L, 2, 0);
        }
    }
    if (!surface)
        sdlI_lua_error(L,"SDL_CreateRGBSurfaceFrom: failed to create rgba surface (%s)");
    if (SDL_BlitSurface(surface, NULL, screen, NULL)) // blit into screen
        sdlI_lua_error(L, "SDL_BlitSurface: failed to blit rgba surface (%s)");
    if (SDL_UpdateWindowSurface(win->window))
        sdlI_lua_error(L, "SDL_UpdateWindowSurface: failed to update window surface (%s)");
    SDL_FreeSurface(surface);
    return 0;
}

int it_kills_window_lua(lua_State* L) { // (win_userdata)
    it_frees_window(luaL_checkudata(L, 1, "Window"));
    return 0;
}
