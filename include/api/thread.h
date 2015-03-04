#ifndef API_THREAD_H
#define API_THREAD_H

#include <lua.h>
#include <uv.h>


#include "it.h"
#include "api.h"
#include "luaI.h"

#include "api/thread.h"
#include "api/scope.h"

extern it_threads* it_allocs_thread();

extern void default_thread_init(void* priv);
extern void default_thread_idle(void* priv);

#if UV_VERSION_MAJOR == 0 && UV_VERSION_MINOR == 10 // libuv 0.10
extern void uvI_thread_idle(uv_idle_t* handle, int status);
#elif UV_VERSION_MAJOR >= 1 // libuv >=1.0
extern void uvI_thread_idle(uv_idle_t* handle);
#endif

extern void it_runs_thread(void* priv);
extern void it_inits_thread(it_threads* thread, it_states* ctx);
extern void it_creates_thread(it_threads* thread);
extern void it_safes_thread(it_threads* thread, bool safe);
extern void it_joins_thread(it_threads* thread);
extern void it_stops_thread(it_threads* thread);
extern void it_closes_thread(it_threads* thread);
extern void it_frees_thread(it_threads* thread);


#endif /* API_THREAD_H */

