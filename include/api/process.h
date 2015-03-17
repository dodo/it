#ifndef API_PROCESS_H
#define API_PROCESS_H

#include <lua.h>
#include <sys/time.h>

#include "it.h"
#include "api.h"
#include "uvI.h"
#include "luaI.h"


extern it_processes* it_allocs_process();

extern void it_creates_process(it_processes* process);
extern void it_inits_process(it_processes* process);
extern void it_sigints_process(it_processes* process);
extern void it_closes_process(it_processes* process);
extern void it_frees_process(it_processes* process);

extern void it_exits_process(it_processes* process, int code);
extern void it_shutdowns_process(it_processes* process);

extern double it_gets_time_process();

extern int it_runs_process(lua_State* L, int argc, char *argv[]);


#endif /* API_PROCESS_H */
