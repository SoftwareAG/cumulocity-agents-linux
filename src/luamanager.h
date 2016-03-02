#ifndef LUAMANAGER_H
#define LUAMANAGER_H
#include <srlogger.h>
#include <srluapluginmanager.h>
#include "configdb.h"


class LuaManager: public SrLuaPluginManager
{
public:
        LuaManager(SrAgent &agent, ConfigDB &cdb): SrLuaPluginManager(agent),
                                                   cdb(cdb) {}
        virtual ~LuaManager() {}
protected:
        void init(lua_State *L) {
                SrLuaPluginManager::init(L);
                getGlobalNamespace(L)
                        .beginClass<ConfigDB>("ConfigDB")
                        .addFunction("get", &ConfigDB::get)
                        .addFunction("set", &ConfigDB::set)
                        .endClass();
                push(L, &cdb);
                lua_setglobal(L, "cdb");
        }
private:
        ConfigDB &cdb;
};

#endif /* LUAMANAGER_H */
