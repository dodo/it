#include <uv.h>

#include <AL/al.h>
#include <AL/alc.h>

#include "it.h"
#include "api.h"
#include "luaI.h"

#include "audio.h"



void it_inits_audio(it_audios* audio,
                    const ALCchar *devicename,
                    const ALCint* attrlist,
                    int nsource) {
    if (!audio) return;
    audio->dev = alcOpenDevice(devicename);
    if (!audio->dev) return;
    audio->ctx = alcCreateContext(audio->dev, attrlist);
    if (!audio->ctx) return;
    if (!alcMakeContextCurrent(audio->ctx))
        it_errors("failed to make context current!");

    if (nsource > 0) {
        audio->sources = (ALuint*) calloc(nsource, sizeof(ALuint));
        if (!audio->sources) return;
        alGenSources(nsource, audio->sources);
    }
    audio->nsource = nsource;
}

void it_frees_audio(it_audios* audio) {
    if (!audio) return;
    if (it_unrefs((it_refcounts*) audio) > 0) return;
    if (audio->ctx) {
        ALCcontext* ctx = audio->ctx;
        audio->ctx = NULL;
        // might take a while …
        alcDestroyContext(ctx);
    }
    if (audio->dev) {
        ALCdevice* dev = audio->dev;
        audio->dev = NULL;
        // might take a while …
        alcCloseDevice(dev);
    }
    if (audio->nsource > 0) {
        audio->nsource = 0;
        free(audio->sources);
    }
}
