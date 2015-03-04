#ifndef API_AUDIO_H
#define API_AUDIO_H

#include <lua.h>

#include <uv.h>

#include <AL/al.h>
#include <AL/alc.h>

#include "it.h"
#include "luaI.h"
#include "audio-types.h"

#include "audio.h"


extern it_audios* it_allocs_audio();
extern void it_inits_audio(it_audios* audio,
                           const ALCchar *devicename,
                           const ALCint* attrlist,
                           int nsource);
extern void it_frees_audio(it_audios* audio);


#endif /* API_AUDIO_H */
