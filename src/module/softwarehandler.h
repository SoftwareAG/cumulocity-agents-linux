#ifndef SOFTWAREHANDLER_H
#define SOFTWAREHANDLER_H
#include <string>
#include <map>
#include <curl/curl.h>
#include <sragent.h>
#include "../configdb.h"

using namespace std;
typedef map<pair<string, string>, string>  SoftwareList;

class SoftwareHandler: public SrMsgHandler
{
public:
        SoftwareHandler(SrAgent &agent, ConfigDB &configDB);
        virtual ~SoftwareHandler();

        void operator()(SrRecord &r, SrAgent &agent);

        SoftwareList getSoftwareList(std::string &host);
        CURLcode deleteSoftware(const string &link);
        CURLcode installSoftware(const string &link, const string &name);

private:
        CURL *curl;
        struct curl_slist *headers;
        std::string data;
        std::string host;
        std::string cred;
        std::string userpass;
        SoftwareList softwareList;
        ConfigDB &cdb;
};

#endif /* SOFTWAREHANDLER_H */
