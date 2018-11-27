#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <fcntl.h>
#include <unistd.h>
#include <inttypes.h>
#include <errno.h>

#define DEF_HW_PART
#include "cal_conf.h"

#include <co_type.h>
#include <co_drv.h>
#include <co_nmt.h>
#include <co_nmt_m.h>
#include <co_sdo.h>
#include <co_odidx.h>
#include <co_guard.h>
#include <co_acces.h>
#include <co_setcp.h>
#include <co_init.h>
#include <co_dynmem.h>
#include <co_util.h>
#include <cdriver.h>
#include <co_lme.h>

#define DEVICENAME	"(m1)"

extern RET_T init_Library(void);

static int SSOCKPORT = 9677;
static int CSOCKPORT = 9678;
UNSIGNED16 bitRate = 125;
UNSIGNED8 lNodeId = 5;
int isFinished = 1;
socklen_t addrlen = sizeof(struct sockaddr_in);
UNSIGNED32 errNo = 0;
char errMsg[128] = {0};

char *retMsg[] = {
        "OK",
        "not enough memory",
        "object not exist",
        "object already exist",
        "operation not allowed",
        "no matching type",     /* 5 */
        "inhibit time active",
        "no initiate service executed",
        "service already running",
        "data type not fit telegram",
        "error type not fit telegram", /* 10 */
        "no network object",
        "invalid range",
        "name length not correct",
        "name syntax not correct",
        "no COB database available", /* 15 */
        "object disabled",
        "syntax error in data- or error type description",
        "syntax error in data type description",
        "syntax error in error type description",
        "mapping error",        /* 20 */
        "no access to object dictionary",
        "object not exist",
        "subindex not exist",
        "no read perm",
        "no write perm",        /* 25 */
        "upper limit",
        "lower limit",
        "object has wrong size",
        "wrong trans type",
        "hardware fault",       /* 30 */
        "param incompatible",
        "unknown sdo error",
        "sdo command specifier invalid",
        "invalid sdo block size",
        "invalid block seq number", /* 35 */
        "invalid sdo block CRC",
        "no resource for sdo connection",
        "bad requested error control mechanism",
        "sdo time out",
        "sdo invalid toogle bit", /* 40 */
        "sdo invalid trans mode",
        "bad device state",
        "bad CRC",
        "service not allowed",
        "CAN transmit buffer full", /* 45 */
        "CAN transmit error",
        "CAN transmit timeout",
        "CAN bad COB type",
        "unknown node",
        "no NMT startup master", /* 50 */
        "bad node id",
        "bad timer value",
        "sdo abort code",
        "internal incompatible",
        "data type size too high", /* 55 */
        "data type size too low",
        "max less than min",
        "data can not transferred",
        "no objection dictionary",
        "message one",          /* 60 */
        "message two"
};

extern char can_device CO_REDCY_PARA_ARRAY_DEF [30];

int co_debug = 0;

#define T_BOOL 0x00
#define T_INT 0x40
#define T_UINT 0x80
#define T_REAL 0xc0
#define NODE_MAX 32
#define OD_MAX 32
#define ELEM_MAX 2048

struct NodeDB {
        UNSIGNED8 node[NODE_MAX];
        UNSIGNED8 od[NODE_MAX];
        UNSIGNED8 nsize;
};

struct ODElem {
        UNSIGNED16 index;
        UNSIGNED8 subIndex;
        UNSIGNED8 type;
};

struct OD {
        UNSIGNED32 id[OD_MAX];  /* Cumulocity ManagedObject ID */
        UNSIGNED16 nsize;       /* number of Object Dictionary */
        UNSIGNED16 nelem[OD_MAX];       /* number of elem */
        struct ODElem elem[OD_MAX][ELEM_MAX];
};

#ifdef CONFIG_RCS_IDENT
static char _rcsid[] = "$Id: main.c,v 1.1 2012/07/27 08:51:58 oe Exp $";
#endif


struct co_ctx {
        int ssock;
        struct sockaddr_in remote;
        struct NodeDB nodeDB;
        struct OD od;
};


static char* getRetMsg(int err)
{
        if (err >= 0 && err < 62)
                return retMsg[err];
        else if (err == 99)
                return "sdo indication busy";
        else
                return "unknown error";
}


static RET_T addClientSdo(int sdoNr, int NodeID)
{
        RET_T commonRet;
        commonRet = setCobId(0x1280 + sdoNr - 1, 1, 0x600 + NodeID);
        printf("sdoNr %d setCobId 0x600: %02x\n", sdoNr, (int)commonRet);
        commonRet = setCobId(0x1280 + sdoNr - 1, 2, 0x580 + NodeID);
        printf("sdoNr %d setCobId 0x580: %02x\n", sdoNr, (int)commonRet);
        return commonRet;
}


static int OD_Init(struct OD *od)
{
        od->nsize = 0;
        return 0;
}


static int OD_Find(struct OD *od, UNSIGNED32 id)
{
        for (int i = 0; i < od->nsize; ++i) {
                if (od->id[i] == id)
                        return i;
        }
        return -1;
}


static int OD_Add(struct OD *od, UNSIGNED32 id)
{
        if (od->nsize >= OD_MAX) {
                errNo = -1;
                strcpy(errMsg, "Object Dictionary exhausted");
                return -1;
        }
        int idx = OD_Find(od, id);
        if (idx != -1) return idx;
        const UNSIGNED16 i = od->nsize++;
        od->id[i] = id;
        od->nelem[i] = 0;
        return i;
}


static int OD_FindElem(struct OD *od, int idx, UNSIGNED16 index,
                       UNSIGNED8 subIndex)
{
        for (int i = 0; i < od->nelem[idx]; ++i) {
                if (od->elem[idx][i].index == index &&
                    od->elem[idx][i].subIndex == subIndex)
                        return i;
        }
        return -1;
}


static int OD_AddElem(struct OD *od, UNSIGNED32 id, UNSIGNED16 index,
                      UNSIGNED8 subIndex, UNSIGNED8 type)
{
        int i = OD_Find(od, id);
        if (i == -1) {
                errNo = -1;
                strcpy(errMsg, "Object Dictionary not found");
                return -1;
        }
        if (od->nelem[i] >= ELEM_MAX) {
                errNo = -1;
                strcpy(errMsg, "element table exhausted");
                return -1;
        }
        int j = OD_FindElem(od, i, index, subIndex);
        if (j != -1) return j;
        j = od->nelem[i]++;
        od->elem[i][j].index = index;
        od->elem[i][j].subIndex = subIndex;
        od->elem[i][j].type = type;
        return j;
}


static int NodeDB_Init(struct NodeDB *nodeDB)
{
        nodeDB->nsize = 0;
        return 0;
}


static int NodeDB_Find(struct NodeDB *nodeDB, UNSIGNED8 node)
{
        for (int i = 0; i < nodeDB->nsize; ++i) {
                if (nodeDB->node[i] == node)
                        return i;
        }
        return -1;
}


static int NodeDB_Add(struct NodeDB *nodeDB, UNSIGNED8 node, UNSIGNED32 od)
{
        if (nodeDB->nsize >= NODE_MAX) {
                errNo = -1;
                strcpy(errMsg, "node table exhausted");
                return -1;
        }
        int i = NodeDB_Find(nodeDB, node);
        if (i != -1) return i;
        i = nodeDB->nsize;
        addClientSdo(node, node);
        nodeDB->node[i] = node;
        nodeDB->od[i] = od;
        ++nodeDB->nsize;
        return i;
}


static int NodeDB_Remove(struct NodeDB *nodeDB, UNSIGNED8 node)
{
        int idx = NodeDB_Find(nodeDB, node);
        if (idx == -1) return nodeDB->nsize;
        int size = nodeDB->nsize - idx - 1;
        memmove(nodeDB->node + idx, nodeDB->node + idx + 1, size);
        memmove(nodeDB->od + idx, nodeDB->od + idx + 1, size);
        return --nodeDB->nsize;
}


static int createSocket()
{
        int ssock;
        if ((ssock = socket(PF_INET, SOCK_DGRAM, 0)) == -1) {
                perror("socket");
                return -1;
        }
        struct sockaddr_in addr;
        memset(&addr, 0, sizeof(addr));
        addr.sin_family = AF_INET;
        addr.sin_addr.s_addr = htonl(INADDR_ANY);
        addr.sin_port = htons(SSOCKPORT);
        int rc = bind(ssock, (struct sockaddr*)&addr, sizeof(addr));
        if (rc == -1) {
                perror("bind");
                return -1;
        }
        return ssock;
}


static int co_ctx_init(struct co_ctx *ctx)
{
        ctx->remote.sin_family = AF_INET;
        ctx->remote.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
        ctx->remote.sin_port = htons(CSOCKPORT);
        ctx->ssock = createSocket();
        NodeDB_Init(&ctx->nodeDB);
        OD_Init(&ctx->od);
        return 0;
}


static int getValue(char *dest, uint64_t value, uint8_t type)
{
        const int num = (type & 0x0f) * 8;
        const uint64_t mask = 0xffffffffffffffff >> (64 - num);
        const uint64_t sign = (value >> (num - 1)) & 0x01;
        switch (type & 0xf0) {
        case T_BOOL: sprintf(dest, "%" PRIu64, value & 0x01); break;
        case T_UINT: sprintf(dest, "%" PRIu64, value & mask); break;
        case T_INT:
                if (sign) {
                        sprintf(dest, "-%" PRIu64, (value ^ mask) + 1);
                } else {
                        sprintf(dest, "%" PRIu64, value);
                }
                break;
        case T_REAL:
                if (num == 32) {
                        uint32_t val = value & 0xffffffff;
                        float *fp = (float*)&val;
                        sprintf(dest, "%f", *fp);
                } else if (num == 64) {
                        double *dp = (double*)&value;
                        sprintf(dest, "%f", *dp);
                }
                break;
        }
        return -1;
}


static UNSIGNED8 getType(const char *s, int n)
{
        n /= 8;
        if (strncmp(s, "boolean", 7) == 0)
                return T_BOOL | 0x01;
        else if (strncmp(s, "unsigned", 8) == 0)
                return T_UINT | n;
        else if (strncmp(s, "signed", 6) == 0)
                return T_INT | n;
        else if (strncmp(s, "real", 4) == 0)
                return T_REAL | n;
        return T_BOOL | 0x01;
}


static int notifyResp(struct co_ctx *ctx, const char *msg)
{
        int sock = ctx->ssock;
        const struct sockaddr *dest = (struct sockaddr*)&ctx->remote;
        int rc = sendto(sock, msg, strlen(msg), 0, dest, addrlen);
        if (rc == -1)
                perror("sendto");
        return rc;
}


static int notifySDO(struct co_ctx *ctx, const char *entity, UNSIGNED8 node,
                     struct ODElem *elem, uint64_t val)
{
        char buf[256], ch[40];
        UNSIGNED16 index = elem->index;
        UNSIGNED8 sub = elem->subIndex;
        getValue(ch, val, elem->type);
        printf("===value: %" PRIx64 ", ch: %s\n", val, ch);
        const char *fmt = "%s %d %d %d %s";
        snprintf(buf, sizeof(buf), fmt, entity, node, index, sub, ch);
        return notifyResp(ctx, buf);
}


static int notifyError(struct co_ctx *ctx, const char *entity)
{
        char buf[256];
        snprintf(buf, sizeof(buf), "%s %u %s", entity, errNo, errMsg);
        return notifyResp(ctx, buf);
}


static int notifySDOError(struct co_ctx *ctx, const char *entity,
                          UNSIGNED8 node, struct ODElem *elem)
{
        UNSIGNED16 index = elem->index;
        UNSIGNED8 subIndex = elem->subIndex;
        char buf[256];
        snprintf(buf, sizeof(buf), "%s %d %d %d %u %s", entity, node,
                 index, subIndex, errNo, errMsg);
        return notifyResp(ctx, buf);
}


static int readSDO(UNSIGNED8 sdoNr, struct ODElem *elem, uint64_t *val)
{
        UNSIGNED16 index = elem->index;
        UNSIGNED8 sub = elem->subIndex;
        UNSIGNED32 size = elem->type & 0x0f;
        UNSIGNED8 *pval = (UNSIGNED8*)val;
        UNSIGNED32 timeOut = 10000;	/* 10000 * 1/10 msec */
        isFinished = 0;
        RET_T ret = readSdoReq(sdoNr, index, sub, pval, size, timeOut);
        char *fmt = "---readSdo %d %x %x: %02x\n";
        printf(fmt, sdoNr, index, sub, (int)ret);
        if (ret != CO_OK) {
                errNo = ret;
                strcpy(errMsg, getRetMsg(errNo));
                return -1;
        }
        while (!isFinished)
                FlushMbox();
        if (errNo) {
                printf("===readSdo: %s\n", errMsg);
                return -1;
        }
        return 0;
}


static int writeSDO(UNSIGNED8 sdoNr, struct ODElem *elem, char *valbuf)
{
        UNSIGNED16 index = elem->index;
        UNSIGNED8 sub = elem->subIndex;
        UNSIGNED32 size = elem->type & 0x0f;
        UNSIGNED32 timeout = 10000;
        UNSIGNED8 *pval = NULL;
        uint64_t val = 0;
        double val2 = 0;
        int64_t val3 = 0;
        float val4 = 0;
        if ((elem->type & 0xf0) == T_REAL) {
                if (size == 4) {
                        val4 = atof(valbuf);
                        pval = (UNSIGNED8*)&val4;
                } else {
                        val2 = atof(valbuf);
                        pval = (UNSIGNED8*)&val2;
                }
        } else if((elem->type & 0xf0) == T_INT) {
                val3 = atoll(valbuf);
                pval = (UNSIGNED8*)&val3;
        } else {
                val = strtoull(valbuf, NULL, 0);
                pval = (UNSIGNED8*)&val;
        }
        isFinished = 0;
        RET_T ret = writeSdoReq(sdoNr, index, sub, pval, size, timeout);
        char *fmt = "---writeSdo: %u %x %x %2x %s: 0x%02x\n";
        printf(fmt, sdoNr, index, sub, elem->type, valbuf, (int)ret);
        if (ret != CO_OK) {
                errNo = ret;
                strcpy(errMsg, getRetMsg(errNo));
                printf("===writeSdo: %s\n", errMsg);
                return -1;
        }
        while (!isFinished)
                FlushMbox();
        if (errNo) {
                printf("===writeSdo: %s\n", errMsg);
                return -1;
        }
        return 0;
}


static int polling(struct co_ctx *ctx)
{
        int ret = 0;
        for (int i = 0; i < ctx->nodeDB.nsize; ++i) {
                UNSIGNED8 node = ctx->nodeDB.node[i];
                int idx = ctx->nodeDB.od[i];
                for (int j = 0; j < ctx->od.nelem[idx]; ++j) {
                        struct ODElem *elem = &ctx->od.elem[i][j];
                        uint64_t val = 0;
                        int rc = readSDO(node, elem, &val);
                        ret = rc ? 0xff : ret;
                        if (rc == 0) {
                                notifySDO(ctx, "sdo", node, elem, val);
                        } else {
                                notifySDOError(ctx, "sdoError", node, elem);
                        }
                }
        }
        printf("----------------------------------------\n");
        return ret;
}


static int startCan(struct co_ctx *ctx)
{
        char buf[256];
        char s[16] = {0};
        while (1) {
                if (read(ctx->ssock, buf, sizeof(buf)) <= 0)
                        continue;
                const char *fmt = "startCan %s %hhu %hu";
                int rc = sscanf(buf, fmt, s, &lNodeId, &bitRate);
                if (rc == 3) {
                        break;
                } else {
                        printf("startCan: wrong command %s\n", buf);
                        continue;
                }
        }
        printf("%s\n", buf);
        UNSIGNED8 rc = iniDevice();
        printf("iniDevice: 0x%02x\n", rc);
        sprintf(GL_DRV_ARRAY(can_device), "/dev/%s", s);
        rc = initCan(bitRate);
        printf("initCan: 0x%02x\n", rc);
        if (rc) {
                errNo = rc;
                strcpy(errMsg, "initCan error");
                return -1;
        }
        RET_T ret = init_Library();
        printf("initLibrary: 0x%02x\n", (int)ret);
        if (ret != CO_OK) {
                errNo = ret;
                strcpy(errMsg, getRetMsg(ret));
                return -1;
        }
        if (initTimer()) {
                errNo = errno;
                strcpy(errMsg, "initTimer error");
        }
        Start_CAN();
        return 0;
}


static int proccessCmd(struct co_ctx *ctx)
{
        char buf[256] = {0};
        if (read(ctx->ssock, buf, sizeof(buf)) <= 0)
                return 0;
        if (strncmp(buf, "addNode ", 5) == 0) {
                int node = 0, id = 0;
                sscanf(buf + 8, "%d %d", &node, &id);
                printf("addNode %d %d\n", node, id);
                int od = OD_Find(&ctx->od, id);
                od = od == -1 ? OD_Add(&ctx->od, id) : od;
                if (od == -1)
                        return notifyError(ctx, "addNodeError");
                if (NodeDB_Add(&ctx->nodeDB, node, od) == -1)
                        return notifyError(ctx, "addNode");
                else
                        return notifyResp(ctx, "addNode OK");
        } else if (strncmp(buf, "addReg ", 4) == 0) {
                int index = 0, subIndex = 0, n = 0, id = 0;
                char s[32] = {0};
                char *fmt = "%d %d %d %8[a-z]%d";
                sscanf(buf + 7, fmt, &id, &index, &subIndex, s, &n);
                UNSIGNED8 type = getType(s, n);
                fmt = "addReg %d %d %d %s%d\n";
                printf(fmt, id, index, subIndex, s, n);
                if (OD_AddElem(&ctx->od, id, index, subIndex, type) == -1) {
                        return notifyError(ctx, "addRegError");
                } else {
                        return notifyResp(ctx, "addReg OK");
                }
        } else if (strncmp(buf, "poll", 4) == 0) {
                int rc = polling(ctx);
                return rc;
        } else if (strncmp(buf, "setBaud ", 8) == 0) {
                int baud = atoi(buf + 8);
                int rc = Set_Baudrate(baud, NULL);
                printf("setBaud: %d (0x%02x)\n", baud, rc);
                if (rc == CO_INIT_CAN_OK) {
                        return notifyResp(ctx, "setBaud OK");
                } else {
                        errNo = rc;
                        strcpy(errMsg, "invalid bitrate");
                        return notifyError(ctx, "setBaudError");
                }
        } else if (strncmp(buf, "removeNode ", 11) == 0) {
                int node = atoi(buf + 11);
                printf("removeNode: %d\n", node);
                NodeDB_Remove(&ctx->nodeDB, node);
                return notifyResp(ctx, "removeNode OK");
        } else if (strncmp(buf, "wrSdo ", 6) == 0) {
                int node = 0, index = 0, sub = 0, n = 0;
                char valbuf[64] = {0}, typebuf[64];
                char *fmt = "%d %d %d %8[a-z]%d %s";
                sscanf(buf + 6, fmt, &node, &index, &sub, typebuf, &n, valbuf);
                UNSIGNED8 type = getType(typebuf, n);
                struct ODElem elem = {index, sub, type};
                addClientSdo(node, node);
                int rc = writeSDO(node, &elem, valbuf);
                if (rc == 0) {
                        return notifyResp(ctx, "wrSdo OK");
                } else {
                        return notifySDOError(ctx, "wrSdoError", node, &elem);
                }
        } else if (strncmp(buf, "rdSdoTimeout ", 13) == 0) {
                printf("%s\n", buf);
                return notifyResp(ctx, "rdSdoTimeout 1000");
        } else if (strncmp(buf, "rdSdo ", 6) == 0) {
                int node = 0, index = 0, sub = 0, n = 0;
                char typebuf[64];
                char *fmt = "%d %d %d %8[a-z]%d";
                uint64_t val = 0;
                sscanf(buf + 6, fmt, &node, &index, &sub, typebuf, &n);
                UNSIGNED8 type = getType(typebuf, n);
                struct ODElem elem = {index, sub, type};
                addClientSdo(node, node);
                int rc = readSDO(node, &elem, &val);
                if (rc == 0) {
                        return notifySDO(ctx, "rdSdo", node, &elem, val);
                } else {
                        notifySDOError(ctx, "rdSdoError", node, &elem);
                        return 0xff;
                }
        } else if (strncmp(buf, "startCan ", 9) == 0) {
                return notifyResp(ctx, "startCan OK");
        } else {
                printf("cmd: unknown command %s\n", buf);
                return -1;
        }
}


static int restartCan(struct NodeDB *nodeDB)
{
        printf("restartCan...\n");
        Stop_CAN();
        /* ResetIntMask(); */
        releaseTimer();
        deinit_Library();
        releaseCan();

        UNSIGNED8 rc = initCan(bitRate);
        printf("initCan: 0x%02x\n", rc);
        if (rc) {
                errNo = rc;
                strcpy(errMsg, "initCan error");
                printf("initCan: %s\n", errMsg);
                return -1;
        }
        rc = init_Library();
        printf("initLibrary: 0x%02x\n", (int)rc);
        if (rc != CO_OK) {
                errNo = rc;
                strcpy(errMsg, getRetMsg(rc));
                printf("init_Library: %s\n", errMsg);
                return -1;
        }
        if (initTimer()) {
                errNo = errno;
                strcpy(errMsg, "initTimer error");
                printf("initTimer: error\n");
        }
        for (int i = 0; i < nodeDB->nsize; ++i) {
                addClientSdo(nodeDB->node[i], nodeDB->node[i]);
        }
        Start_CAN();
        ENABLE_CPU_INTERRUPTS();
        coSetNodeOPERATIONAL();
        return 0;
}


int main()
{
        struct co_ctx ctx;
        co_ctx_init(&ctx);
        if (startCan(&ctx) == 0) {
                notifyResp(&ctx, "startCan OK");
        } else {
                notifyError(&ctx, "startCan");
        }
        proccessCmd(&ctx);
        ENABLE_CPU_INTERRUPTS();
        coSetNodeOPERATIONAL();
        printf("Device has been initialised\n");

        while (1) {
                int rc = proccessCmd(&ctx);
                if (rc == 0xff) {
                        restartCan(&ctx.nodeDB);
                }
        }
        Stop_CAN();
        ResetIntMask();
        releaseTimer();
        deinit_Library();
        return(0);
}
