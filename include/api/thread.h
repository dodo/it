#ifndef API_THREAD_H
#define API_THREAD_H

#include <lua.h>
#include <uv.h>


#include "it.h"
#include "api.h"
#include "luaI.h"

#include "api/thread.h"
#include "api/scope.h"


extern void default_thread_init(void* priv);
extern void default_thread_idle(void* priv);

extern void uvI_thread_idle(uv_idle_t* handle, int status);

extern void it_runs_thread(void* priv);
extern void it_inits_thread(it_threads* thread, it_states* ctx);
extern void it_creates_thread(it_threads* thread);
extern void it_closes_thread(it_threads* thread);
extern void it_frees_thread(it_threads* thread);


#endif /* API_THREAD_H */

