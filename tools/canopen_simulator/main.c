/*++ Application behaviour:
*
*++ The 1st RPDO and a SDO access to object 0x2000 0 sets the variable
*++ actual_u32 = setpoint_u32;
*++ For each access to the applications part of the object dictionary
*++ the variable actual_u32 is incremented.
*++ If actual_u32 > 10 then PDO 2 will be sent.
*++ If actual_u32 will be set by PDO or SDO more than 20 to their previous value
*++ TPDO 1 will be sent.
*++ Furthermore the object 0x2014 contains the current time and
*++ for multi tasking systems the object 0x2004 contains the process ID.
*-- Die 1. RPDO und ein SDO-Zugriff auf Objekt 0x2000 0 setzt die Variable
*-- actual_u32 = setpoint_u32;

*++ This example demonstrates the downsizing of code by using the
*++ the following defines in the file cal_conf.h:

*\code
*undef CONFIG_SDO_COB_ID   // there is no entry for SDO COB-ID in od
*undef CONFIG_SEG_SDO      // segmented transfer is not supported
*undef CONFIG_LIMITS_CHECK // there are no limit definitions within od
*undef CONFIG_BIT_ENCODING // no bit wise encoding
*\endcode

*++ For timing measurements with this example code
*++ some hardware pins are used.
*++ The pins are controlled with macros in the application code
*++ (SET_BIT(), RESET_BIT()).
*++ Defined are these macros in the hardware dependend driver modules
*++ \e drivers/<hw>/\*
*/

#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <inttypes.h>

#define DEF_HW_PART
#include <cal_conf.h>      /* !!! first file to include for all CANopen */
#ifdef CONFIG_CPU_FAMILY_LINUX
# include <unistd.h>
# include <time.h>
#endif

#include <co_acces.h>
#include <co_sdo.h>
#include <co_pdo.h>
#include <co_drv.h>
#include <co_lme.h>
#include <co_nmt.h>
#include <co_init.h>

#include <examples.h>
#include <cdriver.h>
#include "objects.h"

#ifdef NO_PRINTF_S
# define PRINTRET(s, e) do {						\
			    if ((e) == 0) { PUTCHAR('0'); }		\
			    else { PUTCHAR('1'); err = CO_TRUE; }	\
			  } while(0);
#else
# define PRINTRET(s, e) do {						\
			    PRINTF(s, e);				\
			    if((e) != 0) err = CO_TRUE;			\
			  } while(0);
#endif

UNSIGNED16	bitRate = 10;
UNSIGNED8	lNodeId = 31;
int		co_debug;

#ifdef CONFIG_RCS_IDENT
static char _rcsid[] = "$Id: main.c,v 1.1 2012/07/27 08:15:31 oe Exp $";
#endif

extern char can_device CO_REDCY_PARA_ARRAY_DEF [30];


int main(int argc, char *argv[argc])
{
        RET_T commonRet;
        UNSIGNED8 ret;
        BOOL_T err = CO_FALSE;

        lNodeId = atoi(argv[1]);
        int port = atoi(argv[2]);
        ret = iniDevice();
        PRINTRET("iniDevice: 0x%02x\n", (int)ret);

        sprintf(GL_DRV_ARRAY(can_device), "/dev/can%d", port);

        ret = initCan(CAN_START_BIT_RATE);
        PRINTRET("initCan: 0x%02x\n", (int)ret);
        PRINTF("Using Node ID  %d\n", (int)lNodeId);

        commonRet = init_Library();
        PRINTRET("init_Library: 0x%02x\n", (int)commonRet);

        initTimer();
        Start_CAN();
        ENABLE_CPU_INTERRUPTS();

        coSetNodeOPERATIONAL();
        err = CO_FALSE;
        while (err == CO_FALSE) {
                FlushMbox();
                err = endLoop();
        }

        PRINTF("\nSTOP\n");

        Stop_CAN();
        DISABLE_CPU_INTERRUPTS();
        releaseTimer();
        ResetIntMask();

        deinit_Library();

        PUTCHAR('X');

        return 0;
}
