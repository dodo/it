#ifndef AUDIO_TYPES_H
#define AUDIO_TYPES_H

#include <AL/al.h>
#include <AL/alc.h>

#include "it-types.h"


typedef struct {
    int refc;
    ALCdevice *dev;
    ALCcontext *ctx;
    ALuint *sources;
    ALuint *buffers;
    int nsource;
    int nbuffer;
} it_audios;


#endif /* AUDIO_TYPES_H */

