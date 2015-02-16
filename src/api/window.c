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
    if (count < 0) count = 0;
    if (!count) SDL_Quit();
    return count;
}

void sdlI_free(void* priv) {
    it_frees_window((it_windows*) priv);
}

void sdlI_idle(void* priv) {
    it_windows* win = (it_windows*) priv;
    SDL_Event event;
    if (win->thread->ctx->err) return;
    while (!win->thread->closed && SDL_PollEvent(&event)) {
        if (win->thread->ctx->err) return;
        if (event.type == SDL_QUIT) break;
        // call lua …
        luaI_globalemit(win->thread->ctx->lua, "window", "sdl event");
        lua_pushlightuserdata(win->thread->ctx->lua, &event);
        luaI_pcall_in(win->thread->ctx, 3, 0);
    }
    if (event.type == SDL_QUIT || win->thread->closed) {
        it_closes_window(win);
        return;
    }
    // call lua …
    luaI_globalemit(win->thread->ctx->lua, "window", "need render");
    luaI_pcall_in(win->thread->ctx, 2, 1);
//     it_collectsgarbage_scope(win->thread->ctx);
    if (!lua_toboolean(win->thread->ctx->lua, -1)) {
        // no 'need render' event listener, so we wait here
        SDL_Delay(2); // ms
    }
    lua_pop(win->thread->ctx->lua, 1); // emit return value
}

void it_inits_window(it_windows* win, it_threads* thread) {
    if (!thread) return;
    win->thread = thread;
    thread->priv = win;
    thread->on_idle = sdlI_idle;
    thread->on_free = sdlI_free;
}

void it_creates_window(it_windows* win, const char* title,
                       const int* x, const int* y,
                       int width, int height) {
    sdlI_ref(1);
    if (win->window) it_frees_window(win);
    win->window = SDL_CreateWindow(title,
            (x) ? ((intptr_t) &x) : SDL_WINDOWPOS_UNDEFINED,
            (y) ? ((intptr_t) &y) : SDL_WINDOWPOS_UNDEFINED,
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
    }
}

SDL_Surface* it_surfaces_from_window(it_windows* win, void* data) {
    if (!win->window) return NULL;
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
    if (!win->window) return NULL;
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
    if (!win->window) return NULL;
    SDL_Surface* screen = SDL_GetWindowSurface(win->window);
    if (!screen)
        sdlI_error("SDL_GetWindowSurface: failed to get window surface (%s)");
    return screen; // hopefully gets freed by it_updates_window or it_blits_window
}

void it_blits_window(it_windows* win, SDL_Surface* surface) {
    if (!win->window || !surface) return;
    SDL_Surface* screen = SDL_GetWindowSurface(win->window);
    if (!screen)
        sdlI_error("SDL_GetWindowSurface: failed to get window surface (%s)");
    if (SDL_BlitSurface(surface, NULL, screen, NULL)) // blit into screen
        sdlI_error("SDL_BlitSurface: failed to blit rgba surface (%s)");
    it_updates_window(win);
}

void it_updates_window(it_windows* win) {
    if (!win->window) return;
    if (SDL_UpdateWindowSurface(win->window))
        sdlI_error("SDL_UpdateWindowSurface: failed to update window surface (%s)");
}

void it_locks_window_surface(it_windows* win, SDL_Surface* surface) {
    if (SDL_MUSTLOCK(surface) && SDL_LockSurface(surface))
        sdlI_error("SDL_LockSurface: failed to lock surface (%s)");
}

void it_unlocks_window_surface(it_windows* win, SDL_Surface* surface) {
    if (SDL_MUSTLOCK(surface))
        SDL_UnlockSurface(surface);
}

void it_closes_window(it_windows* win) {
    luaI_globalemit(win->thread->ctx->lua, "window", "close");
    luaI_pcall_in(win->thread->ctx, 2, 0);
    win->thread->on_free = NULL;
//     sdlI_ref(1); // prevent SDL_Quit
    it_frees_window(win);
    it_closes_thread(win->thread);
}

void it_frees_window(it_windows* win) {
    if (!win) return;
    if (it_unrefs((it_refcounts*) win) > 0) return;
    if (win->window) {
        SDL_Window* window = win->window;
        win->window = NULL;
        // might take a while …
        SDL_DestroyWindow(window);
    }
    if (win->renderer) {
        SDL_Renderer* renderer = win->renderer;
        win->renderer = NULL;
        // might take a while …
        SDL_DestroyRenderer(renderer);
    }
    sdlI_ref(-1);
}
