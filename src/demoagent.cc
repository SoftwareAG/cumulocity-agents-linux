#include <algorithm>
#include <fstream>
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

const char *ops = ",\"" Q2(c8y_LogfileRequest) "\"";

static string getDeviceID();
static SrLogLevel getLogLevel(const string &lvl);
static void printInfo(const SrAgent &agent);
static int integrate(SrAgent &agent, ConfigDB &cdb);
static void loadLuaPlugins(LuaManager &lua, ConfigDB &cdb);


int main()
{
        SrWatchdogTimer wdt;
        wdt.start();
        ConfigDB cdb(PKG_DIR"/c8ydemo.conf");
        cdb.load("/etc/c8ydemo.conf");
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
        Integrate igt;
        SrAgent agent(server, deviceID, &igt);
        srInfo("Bootstrap to " + server);
        if (agent.bootstrap(cdb.get("path") + "/credentials")) {
                srCritical("Bootstrap failed.");
                return 0;
        }
        if (integrate(agent, cdb) == -1)
                return 0;
        printInfo(agent);
        agent.send(SrNews("311," + agent.ID() + ops));
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


static string getDeviceID()
{
        ifstream in("/sys/devices/virtual/dmi/id/product_serial");
        auto beg = istreambuf_iterator<char>(in);
        auto pred = [](char c){return isalnum(c);};
        string s;
        copy_if(beg, istreambuf_iterator<char>(), back_inserter(s), pred);
        if (!s.empty())
                return s;
        in.close();
        in.open("/proc/cpuinfo");
        for (string sub; getline(in, sub);) {
                if (sub.compare(0, 6, "Serial") == 0) {
                        copy_if(sub.begin() + 6, sub.end(),
                                back_inserter(s), pred);
                        break;
                }
        }
        return s;
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
