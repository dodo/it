#ifndef IT_TYPES_H
#define IT_TYPES_H

#include <uv.h>
#include <lua.h>
#include <schroedinger/schro.h>
#include <oggz/oggz.h>
#include <SDL.h>

#define stdnon  (FILE*) -1

typedef void (*uvI_thread_callback) (void *priv);

typedef struct {
    lua_State *lua;
    uv_loop_t *loop;
    schro_bool free;
} it_states;


typedef struct {
    it_states *ctx;
    uv_signal_t *sigint;
    int argc; char **argv;
    int exit_code;
} it_processes;

typedef struct {
    it_states *ctx;
    uv_thread_t *thread;
    uv_idle_t *idle;
    uvI_thread_callback init;
    uvI_thread_callback callback;
    uvI_thread_callback free;
    schro_bool closed;
    void* priv;
} it_threads;

typedef struct {
    it_threads* thread;
    SchroEncoder *encoder;
    OGGZ *container;
    ogg_int64_t granulepos;
    ogg_int64_t packetno;
    schro_bool eos_pulled;
    schro_bool started;
    long serialno;
    int frames;
    int length;
    unsigned char *buffer;
} it_encodes;

typedef struct {
    schro_bool free;
    void *buffer;
} it_buffers;

typedef struct {
    SchroFrame *frame;
    int size;
    int width;
    int height;
} it_frames;

typedef struct {
    it_threads* thread;
    SDL_Window *window;
    SDL_Renderer *renderer;
} it_windows;


#endif /* IT_TYPES_H */