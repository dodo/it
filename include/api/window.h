#ifndef API_WINDOW_H
#define API_WINDOW_H

#include <lua.h>
#include <SDL.h>

#include "it.h"
#include "api.h"
#include "luaI.h"
#include "core-types.h"

#include "api/thread.h"


int sdlI_ref(int c);

extern it_windows* it_allocs_window();

extern void default_free_window_close(void* priv);
extern void default_idle_window_emit_need_render(void* priv);

extern void it_inits_window(it_windows* win, it_threads* thread);
extern void it_creates_window(it_windows* win, const char* title,
                              const int* x, const int* y,
                              int width, int height);

extern SDL_Surface* it_surfaces_from_window(it_windows* win, void* data);
extern SDL_Surface* it_surfaces_window(it_windows* win, bool no_rle);
extern SDL_Surface* it_screens_window(it_windows* win);

extern void it_blits_window(it_windows* win, SDL_Surface* surface);
extern void it_updates_window(it_windows* win);

extern void it_locks_window_surface(it_windows* win, SDL_Surface* surface);
extern void it_unlocks_window_surface(it_windows* win, SDL_Surface* surface);

extern void it_pushes_event_window(it_windows* win, SDL_Event* event);

extern void it_closes_window(it_windows* win);
extern void it_frees_window(it_windows* win);


#endif /* API_WINDOW_H */
