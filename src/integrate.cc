#include <srnethttp.h>
#include <srutils.h>
#include "integrate.h"
#define NOCONNECT(x) (x == CURLE_COULDNT_RESOLVE_PROXY ||   \
                      x == CURLE_COULDNT_RESOLVE_HOST ||    \
                      x == CURLE_COULDNT_CONNECT)
using namespace std;


int Integrate::integrate(const SrAgent &agent, const string &srv,
                         const string &srt)
{
        SrNetHttp http(agent.server()+"/s", srv, agent.auth());
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
                if (http.post("301,20") <= 0)
                        return -1;
                sr.reset(http.response());
                r = sr.next();
                if (r.size() == 3 && r[0].second == "801") {
                        id = r[2].second;
                        string s = "302," + id + "," + agent.deviceID();
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
