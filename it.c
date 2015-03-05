#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "it-types.h"
#include "luaI.h"
#include "uvI.h"
#include "it.h"

#include "api/process.h"

int main(int argc, char *argv[]) {
    return it_runs_process(NULL, argc, argv);
}
