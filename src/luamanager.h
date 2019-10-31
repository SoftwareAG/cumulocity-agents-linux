#ifndef LUAMANAGER_H
#define LUAMANAGER_H
#include <srnethttp.h>
#include <srlogger.h>
#include <srluapluginmanager.h>
#include "configdb.h"
#ifdef PLUGIN_MODBUS
#include "modbus/mbmanager.h"
#endif
uint64_t bitAnd(uint64_t value, uint64_t mask);

class LuaManager: public SrLuaPluginManager
{
public:
        LuaManager(SrAgent &agent, ConfigDB &db):
                SrLuaPluginManager(agent),
                http(agent.server() + "/s", agent.XID(), agent.auth()),
                db(db) {}
        virtual ~LuaManager() {}

protected:
        void init(lua_State *L) {
                SrLuaPluginManager::init(L);
                getGlobalNamespace(L)
                        .addFunction("bitAnd", bitAnd)
                        .beginClass<ConfigDB>("ConfigDB")
                        .addFunction("get", &ConfigDB::get)
                        .addFunction("set", &ConfigDB::set)
                        .addFunction("save", &ConfigDB::save)
#ifdef PLUGIN_MODBUS
                        .endClass()
                        .beginClass<ModbusBase>("_ModbusBase")
                        .addFunction("poll", &ModbusBase::poll)
                        .addFunction("getCoilValue", &ModbusBase::getCoilValue)
                        .addFunction("getRegValue", &ModbusBase::getRegValue)
                        .addFunction("size", &ModbusBase::size)
                        .addFunction("updateCO", &ModbusBase::updateCO)
                        .addFunction("updateHRBits", &ModbusBase::updateHRBits)
                        .addFunction("errMsg", &ModbusBase::errMsg)
                        .addProperty("timeout", &ModbusBase::timeout,
                                     &ModbusBase::setTimeout)
                        .endClass()
                        .deriveClass<ModbusTCP, ModbusBase>("ModbusTCP")
                        .endClass()
                        .deriveClass<ModbusRTU, ModbusBase>("ModbusRTU")
                        .addFunction("setConf", &ModbusRTU::setConf)
                        .endClass()
                        .beginClass<MBManager>("MBManager")
                        .addConstructor<void (*) ()> ()
                        .addFunction("newTCP", &MBManager::newTCP)
                        .addFunction("newRTU", &MBManager::newRTU)
                        .addFunction("newModel", &MBManager::newModel)
                        .endClass()
                        .beginClass<ModbusModel>("ModbusModel")
                        .addFunction("addAddress", &ModbusModel::addAddress)
#endif
                        .endClass();
                        .deriveClass<SrNetHttp, SrNetInterface>("SrNetHttp")
                        .addFunction("post", &SrNetHttp::post)
                        .endClass();
                push(L, &db);
                lua_setglobal(L, "cdb");
                push(L, &http);
                lua_setglobal(L, "http");
#ifdef PLUGIN_MODBUS
                push(L, &mb);
                lua_setglobal(L, "MB");
#endif
        }
private:
#ifdef PLUGIN_MODBUS
        MBManager mb;
#endif
        ConfigDB &db;
        SrNetHttp http;
};

#endif /* LUAMANAGER_H */
