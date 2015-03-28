#include "it.h"
#include "luaI.h"

#include "api/window.h"
#include "api/thread.h"

// TODO make thread safe (only main should draw)

int sdlI_ref(int c) {
    static int count = 0;
    if (!count) {
        if (SDL_Init(SDL_INIT_EVERYTHING))
            sdlI_error("SDL_Init: failed to initialize SDL (%s)");
    }
    count += c;
    if (!count) SDL_Quit();
    if (count < 0) count = 0;
    return count;
}

it_windows* it_allocs_window() {
    it_windows* win = (it_windows*) calloc(1, sizeof(it_windows));
    if (!win)
        it_errors("calloc(1, sizeof(it_windows)): failed to allocate window");
    win->refc = 1;
    return win;
}

void default_on_free_window_close(void* priv) {
    it_windows* win = (it_windows*) priv;
    it_closes_window(win);
}

void default_on_idle_window_emit_need_render(void* priv) {
    it_windows* win = (it_windows*) priv;
    if (!win->thread || win->thread->ctx->err) return;
    SDL_Event event;
    while (!win->thread->closed && SDL_PollEvent(&event)) {
        if (!win->thread || win->thread->ctx->err) return;
        if (win->thread->closed) return;
        if (event.type == SDL_QUIT) break;
        // call lua …
        luaI_globalemit(win->thread->ctx->lua, "window", "sdl event");
        lua_pushlightuserdata(win->thread->ctx->lua, &event);
        luaI_pcall_in(win->thread->ctx, 3, 0);
    }
    if (!win || !win->thread || win->thread->closed) return;
    if (event.type == SDL_QUIT) {
        default_on_free_window_close(priv);
        return;
    }
    // call lua …
    luaI_globalemit(win->thread->ctx->lua, "window", "need render");
    luaI_pcall_in(win->thread->ctx, 2, 1);
    if (!win || !win->thread || !win->thread->ctx) return;
//     it_collectsgarbage_scope(win->thread->ctx);
    if (!lua_toboolean(win->thread->ctx->lua, -1)) {
        // no 'need render' event listener, so we wait here
        SDL_Delay(2); // ms
    }
    lua_pop(win->thread->ctx->lua, 1); // emit return value
}

void it_inits_window(it_windows* win, it_threads* thread) {
    if (!win || !thread) return;
    if (win->thread) it_frees_thread(win->thread);
    win->thread = NULL;
    if (!thread->refc) return;
    it_refs((it_refcounts*) thread);
    win->thread = thread;
    thread->priv = win;
    thread->on_idle = default_on_idle_window_emit_need_render;
    thread->on_free = default_on_free_window_close;
}

void it_creates_window(it_windows* win, const char* title,
                       const int* x, const int* y,
                       int width, int height) {
    if (!win) return;
    sdlI_ref(1); // prevent SDL_Quit
    if (win->window) it_closes_window(win);
    win->window = SDL_CreateWindow(title,
            (x) ? ((int)(intptr_t) &x) : SDL_WINDOWPOS_UNDEFINED,
            (y) ? ((int)(intptr_t) &y) : SDL_WINDOWPOS_UNDEFINED,
            width, height, SDL_WINDOW_SHOWN
    );
    if (!win->window)
        sdlI_error("SDL_CreateWindow: failed to create window (%s)");
    win->renderer = SDL_CreateRenderer(win->window, -1, 0);
    if (!win->renderer)
        sdlI_error("SDL_CreateRenderer: failed to create renderer (%s)");
    SDL_RenderClear(win->renderer);
    SDL_RenderPresent(win->renderer);
    { // cache window size in struct to expose it into lua
        int w; int h;
        SDL_GetWindowSize(win->window, &w, &h);
        win->height = h;
        win->width = w;
        win->title = title;
    }
}

SDL_Surface* it_surfaces_from_window(it_windows* win, void* data) {
    if (!win || !win->window) return NULL;
    SDL_Surface* surface = SDL_CreateRGBSurfaceFrom(
            data, win->width, win->height, 32, 4 * win->width,
            0x00ff0000, // Rmask
            0x0000ff00, // Gmask
            0x000000ff, // Bmask
            0xff000000  // Amask
        );
    if (!surface)
        sdlI_error("SDL_CreateRGBSurfaceFrom: failed to create rgba surface (%s)");
    SDL_SetSurfaceRLE(surface, 0);
    return surface; // hopefully gets freed by it_blits_window
}

SDL_Surface* it_surfaces_window(it_windows* win, bool no_rle) {
    if (!win || !win->window) return NULL;
    SDL_Surface* surface = SDL_CreateRGBSurface(
        0, win->width, win->height, 32,
            0x00ff0000, // Rmask
            0x0000ff00, // Gmask
            0x000000ff, // Bmask
            0xff000000  // Amask
    );
    if (!surface)
        sdlI_error("SDL_CreateRGBSurface: failed to create rgba surface (%s)");
    SDL_SetSurfaceRLE(surface, no_rle ? 0 : 1);
    return surface; // hopefully gets freed by it_blits_window
}

SDL_Surface* it_screens_window(it_windows* win) {
    if (!win || !win->window) return NULL;
    SDL_Surface* screen = SDL_GetWindowSurface(win->window);
    if (!screen)
        sdlI_error("SDL_GetWindowSurface: failed to get window surface (%s)");
    return screen; // hopefully gets freed by it_updates_window or it_blits_window
}

void it_blits_window(it_windows* win, SDL_Surface* surface) {
    if (!win || !win->window || !surface) return;
    SDL_Surface* screen = SDL_GetWindowSurface(win->window);
    if (!screen)
        sdlI_error("SDL_GetWindowSurface: failed to get window surface (%s)");
    if (SDL_BlitSurface(surface, NULL, screen, NULL)) // blit into screen
        sdlI_error("SDL_BlitSurface: failed to blit rgba surface (%s)");
    it_updates_window(win);
}

void it_updates_window(it_windows* win) {
    if (!win || !win->window) return;
    if (SDL_UpdateWindowSurface(win->window))
        sdlI_error("SDL_UpdateWindowSurface: failed to update window surface (%s)");
}

void it_locks_window_surface(it_windows* win, SDL_Surface* surface) {
    if (!win || !win->window) return;
    if (SDL_MUSTLOCK(surface) && SDL_LockSurface(surface))
        sdlI_error("SDL_LockSurface: failed to lock surface (%s)");
}

void it_unlocks_window_surface(it_windows* win, SDL_Surface* surface) {
    if (!win || !win->window) return;
    if (SDL_MUSTLOCK(surface))
        SDL_UnlockSurface(surface);
}

void it_pushes_event_window(it_windows* win, SDL_Event* event) {
    if (!win || !win->window) return;
    if (SDL_PushEvent(event) < 0)
        sdlI_error("SDL_PushEvent: failed to push event (%s)");
}

void it_closes_window(it_windows* win) {
    if (!win) return;
    if (win->thread) {
        win->thread->on_free = NULL;
        it_closes_thread(win->thread);
    }
    if (win->renderer) {
        SDL_Renderer* renderer = win->renderer;
        win->renderer = NULL;
        // might take a while …
        SDL_DestroyRenderer(renderer);
    }
    if (win->window) {
        if (win->thread
        &&  win->thread->ctx
        &&  win->thread->ctx->lua) {
            luaI_globalemit(win->thread->ctx->lua, "window", "close");
            luaI_pcall_in(win->thread->ctx, 2, 0);
        }
        SDL_Window* window = win->window;
        win->window = NULL;
        // might take a while …
        SDL_DestroyWindow(window);
        sdlI_ref(-1);
    }
}

void it_frees_window(it_windows* win) {
    if (!win) return;
    // window always referenced in its scope
    if (it_unrefs((it_refcounts*) win) > 0) return;
    it_closes_window(win);
    it_frees_thread(win->thread);
    win->thread = NULL;
}
