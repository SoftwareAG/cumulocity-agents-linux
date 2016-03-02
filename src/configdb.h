#ifndef CONFIGDB_H
#define CONFIGDB_H
#include <string>
#include <unordered_map>


class ConfigDB
{
public:
        ConfigDB(const std::string &fpath) {load(fpath);}
        virtual ~ConfigDB() {}
        int load(const std::string &fpath);
        int save(const std::string &fpath) const;
        void clear() {db.clear();}
        const std::string &get(const std::string &key) {return db[key];}
        void set(const std::string &key, const std::string &value) {
                db[key] = value;
        }
private:
        std::unordered_map<std::string, std::string> db;
};

#endif /* CONFIGDB_H */
