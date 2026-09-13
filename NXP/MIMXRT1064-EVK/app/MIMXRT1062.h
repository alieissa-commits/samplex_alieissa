/*
 * Compatibility header: redirects MIMXRT1062.h from stock NetX Duo driver
 * to MIMXRT1064 device registers without modifying vendor source files.
 */
#ifndef _MIMXRT1062_H_
#define _MIMXRT1062_H_

#include "fsl_device_registers.h"

/*
 * Assign distinct MAC addresses to server and client nodes
 * to prevent address collision on the Renode virtual switch.
 */
#if defined(NETX_CLIENT_NODE)
#define NX_DRIVER_ETHERNET_MAC {0x02, 0x11, 0x22, 0x33, 0x44, 0x53}
#else
#define NX_DRIVER_ETHERNET_MAC {0x02, 0x11, 0x22, 0x33, 0x44, 0x52}
#endif

#endif /* _MIMXRT1062_H_ */
