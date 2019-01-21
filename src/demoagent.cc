#include <algorithm>
#include <fstream>
#include <inttypes.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <srutils.h>
#include <sragent.h>
#include <srdevicepush.h>
#include <srreporter.h>
#include <srlogger.h>
#include "configdb.h"
#include "integrate.h"
#include "helper.h"
#include "module/vnchandler.h"
#include "luamanager.h"

#define Q(x) ",\"\""#x"\"\""
#define Q2(x) "\"\""#x"\"\""

using namespace std;

const char *ops = ",\"" Q2(c8y_Command) Q(c8y_ModbusDevice) Q(c8y_SetRegister)
        Q(c8y_ModbusConfiguration) Q(c8y_SerialConfiguration) Q(c8y_SetCoil)
        Q(c8y_LogfileRequest) Q(c8y_RemoteAccessConnect)
        Q(c8y_CANopenAddDevice) Q(c8y_CANopenRemoveDevice)
        Q(c8y_CANopenConfiguration) "\"";

static string getDeviceID(ConfigDB &cdb);
static SrLogLevel getLogLevel(const string &lvl);
static void printInfo(const SrAgent &agent);
static int integrate(SrAgent &agent, ConfigDB &cdb);
static void loadLuaPlugins(LuaManager &lua, ConfigDB &cdb);

// MQTT is default
#define USE_MQTT

int main()
{
    SrWatchdogTimer wdt;
    wdt.start();

    ConfigDB cdb(PKG_DIR "/cumulocity-agent.conf");
    cdb.load("/etc/cumulocity-agent.conf");
    cdb.load(cdb.get("datapath") + "/cumulocity-agent.conf");

    srLogSetDest(cdb.get("log.path"));
    const uint32_t quota = strtoul(cdb.get("log.quota").c_str(), NULL, 10);
    srLogSetQuota(quota ? quota : 1024); // Default 1024 KB when not set.
    srLogSetLevel(getLogLevel(cdb.get("log.level")));

    string server = cdb.get("server");
    bool isMqtt = false;
    if (server.empty())
    {
        srCritical("No server URL.");
        return 0;
    }
    if (server.compare(0, 4, "mqtt") == 0) {
            isMqtt = true;
            server.replace(0, 4, "http");
    }

    const string deviceID = getDeviceID(cdb);
    if (deviceID.empty())
    {
        srCritical("Cannot read deviceID");
        return 0;
    }

    Integrate igt(wdt);
    SrAgent agent(server, deviceID, &igt);

    // log
    srInfo("Bootstrap to " + server);

    mkdir(cdb.get("datapath").c_str(), 0750);
    if (agent.bootstrap(cdb.get("datapath") + "/credentials"))
    {
        // log
        srCritical("Bootstrap failed.");

        return 0;
    }

    if (integrate(agent, cdb) == -1)
    {
        return 0;
    }

    printInfo(agent);
    agent.send(SrNews("327," + agent.ID() + ops));
    agent.send(SrNews("314," + agent.ID() + ",PENDING"));

    LuaManager lua(agent, cdb);
    loadLuaPlugins(lua, cdb);

    VncHandler vnc(agent);
    Helper helper(agent, wdt);
    SrReporter *rpt = nullptr;
    SrDevicePush *push = nullptr;

    if (isMqtt) {
            const bool isssl = server.substr(0, 5) == "https";
            const string port = isssl ? ":8883" : ":1883";
            rpt = new SrReporter(server + port, agent.deviceID(), agent.XID(),
                                 agent.tenant() + '/' + agent.username(),
                                 agent.password(), agent.egress, agent.ingress);
            // set MQTT keep-alive interval to 180 seconds.
            rpt->mqttSetOpt(SR_MQTTOPT_KEEPALIVE, 180);
    } else {
            rpt = new SrReporter(server, agent.XID(), agent.auth(),
                                 agent.egress, agent.ingress);
            push = new SrDevicePush(server, agent.XID(), agent.auth(),
                                    agent.ID(), agent.ingress);
    }
    if (rpt->start()) {
            srCritical("reporter: start failed");
            return 0;
    }
    if (push && push->start()) {
            srCritical("push: start failed");
            return 0;
    }
    // enter main loop (never returns)
    agent.loop();

    return 0;
}

static string searchPathForDeviceID(const string &path)
{
    ifstream in(path);
    auto beg = istreambuf_iterator<char>(in);
    string s;
    const auto isAlnum = [](char c) { return isalnum(c); };

    copy_if(beg, istreambuf_iterator<char>(), back_inserter(s), isAlnum);

    return s;
}

static string searchTextForSerial(const string &path)
{
    ifstream in(path);
    string s;
    const auto isAlnum = [](char c) { return isalnum(c); };

    for (string sub; getline(in, sub);)
    {
        if (sub.compare(0, 6, "Serial") == 0)
        {
            copy_if(sub.begin() + 6, sub.end(), back_inserter(s), isAlnum);
            break;
        }
    }

    return s;
}

static string getDeviceID(ConfigDB &cdb)
{
    string s;
    auto isValid = [](string id) {
        return any_of(id.begin(), id.end(), ::isalnum) &&
                id.find_first_not_of("0") != string::npos;
    };

    s = cdb.get("id");
    if (isValid(s))
            return s;

    // Devices with BIOS
    s = searchPathForDeviceID("/sys/devices/virtual/dmi/id/product_serial");
    if (isValid(s))
    {
        return s;
    }

    // Raspberry PI
    s = searchTextForSerial("/proc/cpuinfo");
    if (!s.empty())
    {
        return s;
    }

    // Virtual Machine
    s = searchPathForDeviceID("/sys/devices/virtual/dmi/id/product_uuid");
    if (isValid(s))
    {
        return s;
    }

    // AWS Paravirtual Instance
    s = searchPathForDeviceID("/sys/hypervisor/uuid");
    if (isValid(s))
        return s;

    // dbus - interprocess communication (IPC) devices
    s = searchPathForDeviceID("/var/lib/dbus/machine-id");
    if (isValid(s))
    {
        return s;
    }

    // systemd (init system)
    s = searchPathForDeviceID("/etc/machine-id");

    return isValid(s) ? s : "";
}

static SrLogLevel getLogLevel(const string &lvl)
{
    SrLogLevel level = SRLOG_INFO;

    if (lvl == "debug")
    {
        level = SRLOG_DEBUG;
    } else if (lvl == "info")
    {
        level = SRLOG_INFO;
    } else if (lvl == "notice")
    {
        level = SRLOG_NOTICE;
    } else if (lvl == "warning")
    {
        level = SRLOG_WARNING;
    } else if (lvl == "error")
    {
        level = SRLOG_ERROR;
    } else if (lvl == "critical")
    {
        level = SRLOG_CRITICAL;
    }

    return level;
}

static void printInfo(const SrAgent &agent)
{
    srNotice("Credential: " + agent.tenant() + "/" + agent.username() + ":" + agent.password());
    srNotice("Device ID: " + agent.deviceID() + ", ID: " + agent.ID());
    srNotice("XID: " + agent.XID());
}

static int integrate(SrAgent &agent, ConfigDB &cdb)
{
    string srv, srt;

    // log
    srDebug("Read SmartRest template...");

    if (readSrTemplate(cdb.get("path") + "/srtemplate.txt", srv, srt))
    {
        srCritical("Read SmartRest failed.");
        return -1;
    }

    // log
    srDebug("Integrate to " + agent.server());

    if (agent.integrate(srv, srt))
    {
        srCritical("Integrate failed.");
        return -1;
    }

    return 0;
}

static void loadLuaPlugins(LuaManager &lua, ConfigDB &cdb)
{
    const string luapath = cdb.get("path") + "/lua/";
    lua.addLibPath(luapath + "?.lua");
    istringstream iss(cdb.get("lua.plugins"));

    for (string sub; getline(iss, sub, ',');)
    {
        lua.load(luapath + sub + ".lua");
    }
}


uint64_t bitAnd(uint64_t value, uint64_t mask)
{
        return value & mask;
}
