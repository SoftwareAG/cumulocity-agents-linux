#include <string>
#include <fstream>
#include <algorithm>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <srlogger.h>
#include "../../ext/json/single_include/nlohmann/json.hpp"
#include "softwarehandler.h"
using namespace std;
using json = nlohmann::json;


size_t write_data(void *buf, size_t size, size_t nm, void *data)
{
        string *str = (string*)data;
        str->append((char*)buf, size * nm);
        return size * nm;
}


static size_t write_file(void *buf, size_t size, size_t nmemb, void *data)
{
        const size_t n = size * nmemb;
        ofstream *fptr = (ofstream*)data;
        if (n > 0 && !fptr->write((const char *)buf, n))
                return 0;
        return n;
}


string makeSoftwareList(SoftwareList &list, const string &id)
{
        string sl = "319," + id + ",\"";
        for (auto &elem: list) {
                sl += "{\"\"name\"\":\"\"";
                sl += elem.first.first;
                sl += "\"\",\"\"version\"\":\"\"";
                sl += elem.first.second;
                sl += "\"\",\"\"url\"\":\"\"";
                sl += elem.second;
                sl += "\"\"},";
        }
        if (sl.back() == ',')
                sl.pop_back();
        sl += '"';
        return sl;
}


SoftwareHandler::SoftwareHandler(SrAgent &agent, ConfigDB &configDB): cdb(configDB)
{
        // host = "http://xinlei.staging-latest.c8y.io";
        host = cdb.get("edge.server");
        cred = "edge/myAdmin:myAdmin@123";
        userpass = agent.tenant() + "/myAdmin:myAdmin@123";
        agent.addMsgHandler(837, this);
        agent.addMsgHandler(814, this);
        agent.addMsgHandler(815, this);
        curl = curl_easy_init();
        curl_easy_setopt(curl, CURLOPT_FAILONERROR, 1);
        curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_data);
        curl_easy_setopt(curl, CURLOPT_WRITEDATA, &data);
        curl_easy_setopt(curl, CURLOPT_USERPWD, cred.c_str());
        // curl_easy_setopt(curl, CURLOPT_VERBOSE, 1);
        headers = curl_slist_append(NULL, "Content-Type: application/json");
        headers = curl_slist_append(headers, "Accept: application/json");
        curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
        auto sl = getSoftwareList(host);
        string list = makeSoftwareList(sl, agent.ID());
        srDebug(list);
        agent.send(SrNews(list));
}


SoftwareHandler::~SoftwareHandler()
{
        curl_slist_free_all(headers);
        curl_easy_cleanup(curl);
}


void SoftwareHandler::operator()(SrRecord &r, SrAgent &agent)
{
        if (r.value(0) == "837") {
                agent.send("303," + r.value(2) + ",EXECUTING");
                softwareList.clear();
        } else if (r.value(0) == "814") {
                auto pair = make_pair(r.value(2), r.value(3));
                softwareList.emplace(pair, r.value(4));
        } else if (r.value(0) == "815") {
                string opId = r.value(2);
                auto localList = getSoftwareList(host);
                SoftwareList installList, removeList;
                set_difference(begin(softwareList), end(softwareList),
                               begin(localList), end(localList),
                               inserter(installList, begin(installList)));
                set_difference(begin(localList), end(localList),
                               begin(softwareList), end(softwareList),
                               inserter(removeList, begin(removeList)));
                for (auto &elem : installList) {
                        string link = elem.second;
                        string name = elem.first.first;
                        string version = elem.first.second;
                        srInfo("software: install " + name + ", " + link);
                        CURLcode rc = installSoftware(link, name);
                        if (rc != CURLE_OK) {
                                const char *err = curl_easy_strerror(rc);
                                agent.send("304," + opId + "," + err);
                                return;
                        }
                }
                for (auto &elem : removeList) {
                        string link = elem.second;
                        srInfo("software: remove " + elem.first.first + ", " + link);
                        CURLcode rc = deleteSoftware(link);
                        if (rc != CURLE_OK) {
                                const char *err = curl_easy_strerror(rc);
                                agent.send("304," + opId + "," + err);
                        }
                }
                auto sl = getSoftwareList(host);
                string list = makeSoftwareList(sl, agent.ID());
                agent.send(SrNews(list));
                agent.send("303," + opId + ",SUCCESSFUL");
        }
}


SoftwareList SoftwareHandler::getSoftwareList(std::string &host)
{
        SoftwareList list;
        data.clear();
        string uri = host + "/application/applicationsByOwner/edge";
        curl_easy_setopt(curl, CURLOPT_URL, uri.c_str());
        curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, "GET");
        curl_easy_setopt(curl, CURLOPT_HTTPGET, 1);
        CURLcode res = curl_easy_perform(curl);
        if (res != CURLE_OK) {
                srError(string("software: ") + curl_easy_strerror(res));
                return list;
        }
        srDebug(data);
        auto json = json::parse(data);
        auto apps = json["applications"];
        for (auto &elem : apps) {
                const string name = elem["name"].get<string>();
                srDebug("software: name " + name);
                string version = "";
                auto iter = elem.find("manifest");
                if (iter != elem.end() && iter->count("version"))
                        version = elem["manifest"]["version"].get<string>();
                srDebug("software: ver " + version);
                const string url = elem["self"].get<string>();
                list[make_pair(name, version)] = url;
        }
        return list;
}


CURLcode SoftwareHandler::deleteSoftware(const string &link)
{
        curl_easy_setopt(curl, CURLOPT_URL, link.c_str());
        curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, "DELETE");
        CURLcode res = curl_easy_perform(curl);
        if (res != CURLE_OK) {
                srError(string("software: ") + curl_easy_strerror(res));
        }
        return res;
}


CURLcode SoftwareHandler::installSoftware(const string &link, const string &name)
{
        string filename = cdb.get("datapath") + "/" + name + ".zip";
        ofstream out(filename);
        curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, "GET");
        curl_easy_setopt(curl, CURLOPT_HTTPGET, 1);
        curl_easy_setopt(curl, CURLOPT_URL, link.c_str());
        curl_easy_setopt(curl, CURLOPT_USERPWD, userpass.c_str());
        curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_file);
        curl_easy_setopt(curl, CURLOPT_WRITEDATA, &out);

        srInfo("software: download " + link + " to " + filename);
        CURLcode rc = curl_easy_perform(curl);
        curl_easy_setopt(curl, CURLOPT_USERPWD, cred.c_str());
        curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_data);
        curl_easy_setopt(curl, CURLOPT_WRITEDATA, &data);
        if (rc != CURLE_OK) {
                srError(string("software: ") + curl_easy_strerror(rc));
                return rc;
        }

        string url = host + "/application/applications";
        string body = "{\"manifest\":null,\"resourcesUrl\":\"/\",\"type\":\"HOSTED\",";
        body += "\"name\":\"" + name + "\",\"key\":\"" + name + "\",\"contextPath\":\"";
        body += name + "\"}";
        data.clear();
        curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, "POST");
        curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
        curl_easy_setopt(curl, CURLOPT_POSTFIELDS, body.c_str());
        curl_easy_setopt(curl, CURLOPT_POSTFIELDSIZE, body.size());
        // curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
        srDebug("software: create app " + body);
        rc = curl_easy_perform(curl);
        if (rc != CURLE_OK) {
                srError(string("software: ") + curl_easy_strerror(rc));
                return rc;
        }
        srDebug("software: created app " + data);
        json resp = json::parse(data);
        string appLink = resp["self"].get<string>();
        string id = resp["id"].get<string>();
        srInfo("software: install " + name + ", " + appLink);
        // curl_easy_setopt(curl, CURLOPT_HTTPHEADER, NULL);

        data.clear();
        url = appLink + "/binaries";
        curl_mime *mime = curl_mime_init(curl);
        curl_mimepart *field = curl_mime_addpart(mime);
        curl_mime_name(field, "file");
        curl_mime_filename(field, name.c_str());
        curl_mime_filedata(field, filename.c_str());
        curl_mime_type(field, "application/zip");

        struct curl_slist *hlist = curl_slist_append(NULL, "Accept: application/json");
        hlist = curl_slist_append(hlist, "Expect:");
        curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
        curl_easy_setopt(curl, CURLOPT_MIMEPOST, mime);
        curl_easy_setopt(curl, CURLOPT_HTTPHEADER, hlist);
        rc = curl_easy_perform(curl);
        if (rc != CURLE_OK) {
                srError(string("software: ") + curl_easy_strerror(rc));
        }
        curl_mime_free(mime);
        curl_slist_free_all(hlist);
        curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
        srDebug(data);
        resp = json::parse(data);
        string versionId = resp["id"].get<string>();
        body = "{\"id\":\"" + id + "\",\"activeVersionId\":\"" + versionId + "\"}";
        srDebug(body);
        curl_easy_setopt(curl, CURLOPT_URL, appLink.c_str());
        curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, "PUT");
        curl_easy_setopt(curl, CURLOPT_POSTFIELDS, body.c_str());
        curl_easy_setopt(curl, CURLOPT_POSTFIELDSIZE, body.size());
        rc = curl_easy_perform(curl);
        if (rc != CURLE_OK) {
                srError(string("software: ") + curl_easy_strerror(rc));
        }
        return rc;
}
