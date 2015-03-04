#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "it-types.h"
#include "luaI.h"
#include "uvI.h"
#include "it.h"

int main(int argc, char *argv[]) {
    it_processes process;
    // default state values
    process.argc = argc;
    process.argv = argv;
    process.exit_code = -1;
    // create lua state
    if (!luaI_createstate(&process)) {
        // nothing to call!
        return 1;
    }
    // run forest run!
    if (process.exit_code == -1) {
        process.exit_code = 0;
        uv_run(process.loop, UV_RUN_DEFAULT);
    }
    luaI_closestate(&process);
    // return exit code set by lua
    return process.exit_code;
}
