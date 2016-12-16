#include <algorithm>
#include <fstream>
#include <sys/stat.h>
#include <sys/types.h>
#include <srutils.h>
#include <sragent.h>
#include <srdevicepush.h>
#include <srreporter.h>
#include <srlogger.h>
#include "integrate.h"
#include "helper.h"
#include "luamanager.h"
#define Q(x) ",\"\""#x"\"\""
#define Q2(x) "\"\""#x"\"\""
using namespace std;

const char *ops = ",\"" Q2(c8y_Command) Q(c8y_ModbusDevice) Q(c8y_SetCoil)
        Q(c8y_ModbusConfiguration) Q(c8y_SerialConfiguration)
        Q(c8y_LogfileRequest) Q(c8y_SetRegister) "\"";

static string getDeviceID();
static SrLogLevel getLogLevel(const string &lvl);
static void printInfo(const SrAgent &agent);
static int integrate(SrAgent &agent, ConfigDB &cdb);
static void loadLuaPlugins(LuaManager &lua, ConfigDB &cdb);


int main()
{
        SrWatchdogTimer wdt;
        wdt.start();
        ConfigDB cdb(PKG_DIR "/" AGENT_NAME ".conf");
        cdb.load("/etc/" AGENT_NAME ".conf");
        srLogSetDest(cdb.get("log.path"));
        const uint32_t quota = strtoul(cdb.get("log.quota").c_str(), NULL, 10);
        srLogSetQuota(quota ? quota : 1024); // Default 1024 KB when not set.
        srLogSetLevel(getLogLevel(cdb.get("log.level")));
        const string server = cdb.get("server");
        if (server.empty()) {
                srCritical("No server URL.");
                return 0;
        }
        const string deviceID = getDeviceID();
        if (deviceID.empty()) {
                srCritical("Cannot read deviceID");
                return 0;
        }
        Integrate igt(wdt);
        SrAgent agent(server, deviceID, &igt);
        srInfo("Bootstrap to " + server);
        mkdir(cdb.get("datapath").c_str(), 0750);
        if (agent.bootstrap(cdb.get("datapath") + "/credentials")) {
                srCritical("Bootstrap failed.");
                return 0;
        }
        if (integrate(agent, cdb) == -1)
                return 0;
        printInfo(agent);
        agent.send(SrNews("327," + agent.ID() + ops));
        LuaManager lua(agent, cdb);
        loadLuaPlugins(lua, cdb);
        Helper helper(agent, wdt);
        SrReporter reporter(server, agent.XID(), agent.auth(),
                            agent.egress, agent.ingress);
        SrDevicePush push(server, agent.XID(), agent.auth(),
                          agent.ID(), agent.ingress);
        if (reporter.start() || push.start())
                return 0;
        agent.loop();
        return 0;
}


static string searchPathForDeviceID(const string &path)
{
        ifstream in(path);
        auto beg = istreambuf_iterator<char>(in);
        string s;
        auto isAlnum = [](char c){return isalnum(c);};
        copy_if(beg, istreambuf_iterator<char>(), back_inserter(s), isAlnum);
        return s;
}


static string searchTextForSerial(const string &path)
{
        ifstream in(path);
        string s;
        auto isAlnum = [](char c){return isalnum(c);};

        for (string sub; getline(in, sub);) {
                if (sub.compare(0, 6, "Serial") == 0) {
                        copy_if(sub.begin() + 6, sub.end(),
                                back_inserter(s), isAlnum);
                        break;
                }
        }
        return s;
}


static string getDeviceID()
{
        string s;
        auto isValid = [](string id){
                return any_of(id.begin(), id.end(), ::isdigit)
                        && id.find_first_not_of("0") != string::npos;
        };

        // Devices with BIOS
        s = searchPathForDeviceID("/sys/devices/virtual/dmi/id/product_serial");
        if (isValid(s)) return s;

        // Raspberry PI
        s = searchTextForSerial("/proc/cpuinfo");
        if (!s.empty()) return s;

        // Virtual Machine
        s = searchPathForDeviceID("/sys/devices/virtual/dmi/id/product_uuid");
        if (isValid(s)) return s;

        // dbus - interprocess communication (IPC) devices
        s = searchPathForDeviceID("/var/lib/dbus/machine-id");
        if (isValid(s)) return s;

        // systemd (init system)
        s = searchPathForDeviceID("/etc/machine-id");
        return isValid(s) ? s : "";
}


static SrLogLevel getLogLevel(const string &lvl)
{
        if (lvl == "debug") return SRLOG_DEBUG;
        else if (lvl == "info") return SRLOG_INFO;
        else if (lvl == "notice") return SRLOG_NOTICE;
        else if (lvl == "warning") return SRLOG_WARNING;
        else if (lvl == "error") return SRLOG_ERROR;
        else if (lvl == "critical") return SRLOG_CRITICAL;
        else return SRLOG_INFO;
}


static void printInfo(const SrAgent &agent)
{
        srNotice("Credential: " + agent.tenant() + "/" + agent.username() +
                 ":" + agent.password());
        srNotice("Device ID: " + agent.deviceID() + ", ID: " + agent.ID());
        srNotice("XID: " + agent.XID());
}


static int integrate(SrAgent &agent, ConfigDB &cdb)
{
        string srv, srt;
        srDebug("Read SmartRest template...");
        if (readSrTemplate(cdb.get("path") + "/srtemplate.txt", srv, srt)) {
                srCritical("Read SmartRest failed.");
                return -1;
        }
        srDebug("Integrate to " + agent.server());
        if (agent.integrate(srv, srt)) {
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
                lua.load(luapath + sub + ".lua");
}
