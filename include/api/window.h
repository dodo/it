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

extern void sdlI_free(void* priv);
extern void sdlI_idle(void* priv);

extern void it_inits_window(it_windows* win, it_threads* thread);
extern void it_creates_window(it_windows* win, const char* title,
                              const int* x, const int* y,
                              int width, int height);

extern SDL_Surface* it_surfaces_from_window(it_windows* win, void* data);
extern SDL_Surface* it_surfaces_window(it_windows* win);

extern void it_blits_window(it_windows* win, SDL_Surface* surface);
extern void it_frees_window(it_windows* win);


#endif /* API_WINDOW_H */
