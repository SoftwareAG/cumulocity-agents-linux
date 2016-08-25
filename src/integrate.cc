#include <algorithm>
#include <fstream>
#include <srnethttp.h>
#include <srutils.h>
#include "integrate.h"
#define NOCONNECT(x) (x == CURLE_COULDNT_RESOLVE_PROXY ||\
                      x == CURLE_COULDNT_RESOLVE_HOST ||\
                      x == CURLE_COULDNT_CONNECT ||\
                      x == CURLE_OPERATION_TIMEDOUT)
using namespace std;


static void getHardware(string &model, string &revision)
{
        ifstream in("/sys/devices/virtual/dmi/id/product_name");
        in >> model;
        in.close();
        in.open("/sys/devices/virtual/dmi/id/product_version");
        in >> revision;
        in.close();
        if (model.empty()) {
                in.open("/proc/cpuinfo");
                auto foo = [](char c){return isalnum(c);};
                for (string line; getline(in, line);) {
                        if (line.compare(0, 8, "Hardware") == 0) {
                                copy_if(line.begin() + 8, line.end(),
                                        back_inserter(model), foo);
                        } else if (line.compare(0, 8, "Revision") == 0) {
                                copy_if(line.begin() + 8, line.end(),
                                        back_inserter(revision), foo);
                        }
                }
        }
}


int Integrate::integrate(const SrAgent &agent, const string &srv,
                         const string &srt)
{
        SrNetHttp http(agent.server()+"/s", srv, agent.auth());
        http.setTimeout(60);
        int c = 0;
        while ((c = registerSrTemplate(http, xid, srt) == -1) &&
                NOCONNECT(http.errNo)) {
                sleep(2);
                wdt.kick();
        }
        if (c) return -1;
        http.clear();
        if (http.post("300," + agent.deviceID()) <= 0)
                return -1;
        SmartRest sr(http.response());
        SrRecord r = sr.next();
        if (r.size() && r[0].second == "50") {
                http.clear();
                string s = "301,";
                string model, revision;
                getHardware(model, revision);
                s += model.empty() ? "demo-agent" : model + " " + revision;
                s += " (" + agent.deviceID() + "),20";
                if (http.post(s) <= 0)
                        return -1;
                sr.reset(http.response());
                r = sr.next();
                if (r.size() == 3 && r[0].second == "801") {
                        id = r[2].second;
                        s = "302," + id + "," + agent.deviceID();
                        if (!model.empty())
                                s += "\n310," + id + "," + model + ","
                                        + agent.deviceID() + "," + revision;
                        if (http.post(s) <= 0)
                                return -1;
                        return 0;
                }
        } else if (r.size() == 3 && r[0].second == "800") {
                id = r[2].second;
                return 0;
        }
        return -1;
}
