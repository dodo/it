#ifndef ENCODER_TYPES_H
#define ENCODER_TYPES_H

#include <schroedinger/schro.h>
#include <schroedinger/schroencoder.h>
#include <oggz/oggz.h>

#include "it-types.h"


typedef struct _it_encodes {
    int refc;
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

typedef struct _it_frames {
    int refc;
    SchroFrame *frame;
    int size;
    int width;
    int height;
} it_frames;


#endif /* ENCODER_TYPES_H */
