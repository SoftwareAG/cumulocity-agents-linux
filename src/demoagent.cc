#include <sragent.h>
#include <srdevicepush.h>
#include <srreporter.h>
#include <srluapluginmanager.h>
#include <srlogger.h>
#include "integrate.h"
using namespace std;

// static const string &server = "http://management.tindi.solutions";
static const string server = "http://developer.cumulocity.com";
static const char *srpath = "srtemplate.txt";
static const char *deviceID = "123123";
static const char *credpath = "/tmp/c8ydemo";
static const string luapath = "lua/";

static void printInfo(const SrAgent &agent);
static int integrate(SrAgent &agent);


int main()
{
        // srLogSetDest("/var/log/demoagent.log");
        srLogSetQuota(1024);
        srLogSetLevel(SRLOG_DEBUG);
        Integrate igt;
        SrAgent agent(server, deviceID, &igt);
        srInfo("Bootstrap to " + server);
        if (agent.bootstrap(credpath)) {
                srCritical("Bootstrap failed.");
                return 0;
        }
        if (integrate(agent) == -1)
                return 0;
        printInfo(agent);
        SrLuaPluginManager lua(agent);
        lua.addLibPath(luapath + "?.lua");
        lua.load(luapath + "system.lua");
        lua.load(luapath + "logview.lua");
        // lua.load(luapath + "software.lua");
        SrReporter reporter(server, agent.XID(), agent.auth(),
                            agent.egress, agent.ingress);
        SrDevicePush push(server, agent.XID(), agent.auth(),
                          agent.ID(), agent.ingress);
        if (reporter.start() || push.start())
                return 0;
        agent.loop();
        return 0;
}


static void printInfo(const SrAgent &agent)
{
        srNotice("Credential: " + agent.tenant() + "/" + agent.username() +
                 ":" + agent.password());
        srNotice("Device ID: " + agent.deviceID() + ", ID: " + agent.ID());
        srNotice("XID: " + agent.XID());
}


static int integrate(SrAgent &agent)
{
        string srv, srt;
        srDebug("Read SmartRest template...");
        if (readSrTemplate(srpath, srv, srt)) {
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
