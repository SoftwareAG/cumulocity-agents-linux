#include <stdio.h>

#include <cal_conf.h>
#include <co_sdo.h>
#include <co_flag.h>
#include <co_drv.h>
#include <co_usr.h>
#include <co_nmt.h>
#include <co_nmt_m.h>

#include <examples.h>
#include <string.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <arpa/inet.h>

extern UNSIGNED8 lNodeId;
extern int isFinished;
extern UNSIGNED32 errNo;
extern char errMsg[128];

#ifdef CONFIG_RCS_IDENT
static char _rcsid[] = "$Id: usr_301.c,v 1.1 2012/07/27 08:51:58 oe Exp $";
#endif

UNSIGNED8 getNodeId()
{
        return(lNodeId);
}


#ifdef CONFIG_SDO_SERVER
RET_T sdoWrInd(UNSIGNED16 index, UNSIGNED8  subIndex)
{
        (void)index;
        (void)subIndex;
        return(CO_OK);
}


RET_T sdoRdInd(UNSIGNED16 index, UNSIGNED8  subIndex)
{
        (void)index;
        (void)subIndex;
        return(CO_OK);
}
#endif  /* CONFIG_SDO_SERVER */


#ifdef CONFIG_NODE_GUARDING
# ifdef CONFIG_MASTER
void mGuardErrorInd(UNSIGNED8 nodeId, ERROR_SPEC_T kind)
{
        switch(kind) {
        case CO_BOOT_UP:
                PRINTF("BOOT_UP node %u\n",(unsigned int)nodeId);
                startRemoteNodeReq(nodeId);
                break;
        case CO_NODE_STATE:
                PRINTF("Wrong NODE_STATE node %u\n",(unsigned int)nodeId);
                break;
        case CO_LOST_GUARDING_MSG:
                PRINTF("LOST_GUARDING_MSG node %u\n",(unsigned int)nodeId);
                break;
        case CO_LOST_CONNECTION:
                PRINTF("LOST_CONNECTION node %u\n",(unsigned int)nodeId);
                break;
        default:
                break;
        }
}
# endif
#endif


#ifdef CONFIG_CAN_ERROR_HANDLING
BOOL_T canErrorInd(UNSIGNED8 errorFlags)
{
        UNSIGNED8	state;
        BOOL_T		ret = CO_TRUE;

        PRINTF("canErrorInd status changes: ");
        if ((errorFlags & CANFLAG_PASSIVE) != 0)  {
                PRINTF("ERROR_PASSIVE\n");
        }
        if ((errorFlags & CANFLAG_BUSOFF) != 0)  {
                PRINTF("BUS_OFF\n");
                ret = CO_FALSE; /* Auto Bus-On */
        }
        if ((errorFlags & CANFLAG_OVERFLOW) != 0)  {
                PRINTF("OVERRUN\n");
        }
        if ((errorFlags & CANFLAG_RXBUFFER_OVERFLOW) != 0)  {
                PRINTF("ERROR_RXBUFFER_OVERFLOW\n");
        }
        if ((errorFlags & CANFLAG_TXBUFFER_OVERFLOW) != 0)  {
                PRINTF("ERROR_TXBUFFER_OVERFLOW\n");
        }

        state = getCanDriverState();
        PRINTF("The actual state is (%x): ", (unsigned int)state);

        if ((state & CANFLAG_INIT) != 0)  {
                PRINTF("INIT\n");
        }
        if ((state & CANFLAG_ACTIVE) != 0)  {
                PRINTF("Active\n");
        }
        if ((state & CANFLAG_BUSOFF) != 0)  {
                PRINTF("BUS_OFF\n");
        }
        if ((state & CANFLAG_PASSIVE) != 0)  {
                PRINTF("ERROR_PASSIVE\n");
        }

        return(ret);
}
#endif


#ifdef CONFIG_SDO_CLIENT
void sdoWrCon(UNSIGNED8  sdoNr, UNSIGNED32 errorFlag)
{
        errNo = errorFlag;
        printf("sdoWrCon: sdo %d 0x%x\n", (int)sdoNr, (int)errorFlag);
        if (errorFlag == E_SDO_TIMEOUT)  {
                strcpy(errMsg, "timeout");
                isFinished = 1;
                return;
        }

        switch (errorFlag & 0xFF000000UL) {
        case E_SDO_NO_ERROR:
                break;
        case E_SDO_SERVICE:
                switch (errorFlag & 0x00FF0000UL) {
                case E_SDO_INCONS_PARA:
                        strcpy(errMsg, "inconsistent param");
                        break;
                case E_SDO_ILLEG_PARA:
                        strcpy(errMsg, "illegal parameter");
                        break;
                }
                break;
        case E_SDO_ACCESS:
                switch (errorFlag & 0x00FF0000UL) {
                case E_SDO_UNSUPP_ACCESS:
                        switch (errorFlag & 0x00000000FFUL) {
                        case E_SDO_A_NO_WRITE_PERM:
                                strcpy(errMsg, "no write perm");
                                break;
                        case E_SDO_A_NO_READ_PERM:
                                strcpy(errMsg, "no read perm");
                                break;
                        default:
                                strcpy(errMsg, "unsupported object access");
                        }
                        break;
                case E_SDO_NONEXIST_OBJECT:
                        strcpy(errMsg, "non existing index");
                        break;
                case E_PDO_MAPPING:
                        strcpy(errMsg, "mapping fault");
                        break;
                case E_SDO_HARDWARE_FAULT:
                        strcpy(errMsg, "hardware fault");
                        break;
                        /* size of SDO value is not equal the defined size */
                case E_SDO_TYPE_CONFLICT:
                        strcpy(errMsg, "type conflict");
                        break;
                case E_SDO_INCONS_OBJ_ATTR:
                        switch (errorFlag & 0x00000000FFUL) {
                        case E_SDO_A_NONEXIST_SUBINDEX:
                                strcpy(errMsg, "subindex not exist");
                                break;
                        case E_SDO_A_VALUE_TO_HIGH:
                                strcpy(errMsg, "value too high");
                                break;
                        case E_SDO_A_VALUE_TO_LOW:
                                strcpy(errMsg, "value too low");
                                break;
                        case E_SDO_A_INVALID_VAL:
                                strcpy(errMsg, "invalid value");
                                break;
                        case E_SDO_A_VALUE_RANGE_EXCEED:
                                strcpy(errMsg, "inconsistent attr");
                                break;
                        default:
                                strcpy(errMsg, "unkonwn error");
                        }
                }
                break;
        case E_SDO_OTHER:
                strcpy(errMsg, "other error");
                break;
        default:
                strcpy(errMsg, "abort dom transfer");
                break;
        }
        isFinished = 1;
}


void sdoRdCon(UNSIGNED8  sdoNr, UNSIGNED32 errorFlag)
{
        errNo = errorFlag;
        switch (errorFlag & 0xFF000000UL) {
        case E_SDO_NO_ERROR:
                break;
        case E_SDO_SERVICE:
                switch (errorFlag & 0x00FF0000UL) {
                case E_SDO_INCONS_PARA:
                        strcpy(errMsg, "inconsistent param");
                        break;
                case E_SDO_ILLEG_PARA:
                        strcpy(errMsg, "illegal param");
                        break;
                }
                break;
        case E_SDO_ACCESS:
                switch (errorFlag & 0x00FF0000UL) {
                case E_SDO_UNSUPP_ACCESS:
                        switch (errorFlag & 0x00000000FFUL) {
                        case E_SDO_A_NO_WRITE_PERM:
                                strcpy(errMsg, "no write perm");
                        case E_SDO_A_NO_READ_PERM:
                                strcpy(errMsg, "no read perm");
                                break;
                        default:
                                strcpy(errMsg, "unsupported object access");
                        }
                        break;
                case E_SDO_NONEXIST_OBJECT:
                        strcpy(errMsg, "non existing index");
                        break;
                case E_PDO_MAPPING:
                        strcpy(errMsg, "mapping fault");
                        break;
                case E_SDO_HARDWARE_FAULT:
                        strcpy(errMsg, "hardware fault");
                        break;
                        /* size of SDO value is not equal the defined size */
                case E_SDO_TYPE_CONFLICT:
                        strcpy(errMsg, "type conflict");
                        break;
                case E_SDO_INCONS_OBJ_ATTR:
                        switch (errorFlag & 0x00000000FFUL) {
                        case E_SDO_A_NONEXIST_SUBINDEX:
                                strcpy(errMsg, "subindex not exist");
                                break;
                        case E_SDO_A_VALUE_TO_HIGH:
                                strcpy(errMsg, "value to high");
                                break;
                        case E_SDO_A_VALUE_TO_LOW:
                                strcpy(errMsg, "value to low");
                                break;
                        case E_SDO_A_INVALID_VAL:
                                strcpy(errMsg, "invalid value");
                                break;
                        case E_SDO_A_VALUE_RANGE_EXCEED:
                                strcpy(errMsg, " inconsistent attr");
                                break;
                        default:
                                strcpy(errMsg, "unknown error");
                        }
                }
                break;
        case E_SDO_OTHER:
                strcpy(errMsg, "other error");
                break;
        default:
                strcpy(errMsg, "abort dom transfer");
                break;
        }
        isFinished = 1;
}
#endif /* CONFIG_SDO_CLIENT */
