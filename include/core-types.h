#ifndef CORE_TYPES_H
#define CORE_TYPES_H

#include <uv.h>
#include <lua.h>

#include <schroedinger/schro.h>
#include <schroedinger/schroencoder.h>
#include <oggz/oggz.h>
#include <SDL.h>


typedef void (*uvI_thread_callback) (void *priv);

typedef struct {
    it_states *ctx;
    uv_thread_t *thread;
    uv_idle_t *idle;
    uvI_thread_callback on_init;
    uvI_thread_callback on_idle;
    uvI_thread_callback on_free;
    schro_bool closed;
    void* priv;
} it_threads;

typedef struct {
    it_threads *thread;
    it_states *hooks[SCHRO_ENCODER_FRAME_STAGE_LAST];
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
    it_threads *thread;
    SDL_Window *window;
    SDL_Renderer *renderer;
    int width;
    int height;
} it_windows;


#endif /* IT_TYPES_H */