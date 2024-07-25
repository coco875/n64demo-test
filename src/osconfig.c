#include <ultra64.h>
#include "osconfig.h"

u64 bootStack[BOOTSTACKSIZE/sizeof(u64)];
u64 idleThreadStack[IDLESTACKSIZE/sizeof(u64)];
u64 mainThreadStack[MAINSTACKSIZE/sizeof(u64)];