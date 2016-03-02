#include <fstream>
#include <iterator>
#include <algorithm>
#include <srlogger.h>
#include "configdb.h"
using namespace std;


int ConfigDB::load(const string &fpath)
{
        ifstream in(fpath);
        if (!in) {
                srError(fpath + ": open file for read.");
                return -1;
        }
        int c = 0;
        size_t num = 1;
        for (string line; getline(in, line); ++num) {
                const size_t pos = line.find('=');
                if (pos != string::npos) {
                        db[line.substr(0, pos)] = line.substr(pos + 1);
                } else {
                        c = -1;
                        srError(fpath + " [" + to_string(num) +
                                "]: delimiter '=' not found");
                }
        }
        return c;
}


int ConfigDB::save(const string &fpath) const
{
        ofstream out(fpath, ios_base::binary | ios_base::trunc);
        if (!out) {
                srError(fpath + ": open file for write.");
                return -1;
        }
        for (auto &item: db)
                out << item.first << "=" << item.second << endl;
        return 0;
}
