#ifndef CORE_TYPES_H
#define CORE_TYPES_H

#include <uv.h>
#include <lua.h>

#include <SDL.h>


typedef struct _it_windows {
    int refc;
    it_threads *thread;
    SDL_Window *window;
    SDL_Renderer *renderer;
    int width;
    int height;
} it_windows;


#endif /* IT_TYPES_H */
