PLUGIN_MODBUS:=0
BUILD:=debug
SRC_DIR:=src
BUILD_DIR:=build/obj
SRC:=$(wildcard $(SRC_DIR)/*.cc)

ifeq ($(PLUGIN_MODBUS),1)
SRC+=$(wildcard $(SRC_DIR)/modbus/*.cc)
endif

OBJ:=$(addprefix $(BUILD_DIR)/,$(notdir $(SRC:.cc=.o)))

BIN_DIR:=bin
STAGE_DIR:=build/staging
PKG_DIR:=$(PREFIX)/share/c8ydemo
BIN:=c8ydemo-agent
CPPFLAGS+=-I$(C8Y_LIB_PATH)/include $(shell pkg-config --cflags lua libmodbus)\
		  -DPKG_DIR='"$(PKG_DIR)"'
CXXFLAGS+=-Wall -pedantic -Wextra -std=c++11 -MMD
LDFLAGS:=-Llib
LDLIBS:=-lsera $(shell pkg-config --libs lua libmodbus) -pthread

ifeq ($(PLUGIN_MODBUS),1)
CPPFLAGS+=-DPLUGIN_MODBUS
endif

ifeq ($(PREFIX),)
PREFIX:=/usr
endif

ifeq ($(BUILD), release)
CPPFLAGS+=-DNDEBUG
CXXFLAGS+=-O2
LDFLAGS+=-O2 -s -flto
else
CPPFLAGS+=-DDEBUG
CXXFLAGS+=-O0 -g
LDFLAGS+=-O0 -g
endif

.PHONY: all release clean

all: $(BIN_DIR)/$(BIN)
	@:

release:
	@make -s "BUILD=release"

install:
	@mkdir -p $(PREFIX)/bin
	@cp $(BIN_DIR)/$(BIN) $(BIN_DIR)/srwatchdogd $(PREFIX)/bin
	@cp -rP lib/ $(PREFIX)
	@mkdir -p $(PKG_DIR)
	@cp -rP lua srtemplate.txt COPYRIGHT $(PKG_DIR)
	@sed -e 's#\$$PKG_DIR#$(PKG_DIR)#g' c8ydemo.conf > $(PKG_DIR)/c8ydemo.conf
	@test -d /lib/systemd/system && sed 's#$$PREFIX#$(PREFIX)#g' utils/c8ydemo.service > /lib/systemd/system/c8ydemo.service
	@touch /etc/c8ydemo.conf

debian:
	@mkdir -p $(STAGE_DIR)/$@$(PREFIX)/bin
	@cp $(BIN_DIR)/$(BIN) $(BIN_DIR)/srwatchdogd $(STAGE_DIR)/$@$(PREFIX)/bin
	@mkdir -p $(STAGE_DIR)/$@$(PREFIX)/lib
	@cp -P lib/libsera.so.1* $(STAGE_DIR)/$@$(PREFIX)/lib
	@chmod -x $(STAGE_DIR)/$@$(PREFIX)/lib/*
	@mkdir -p $(STAGE_DIR)/$@$(PKG_DIR)
	@cp -rP lua srtemplate.txt $(STAGE_DIR)/$@$(PKG_DIR)
	@sed 's#$$PKG_DIR#$(PKG_DIR)#g' c8ydemo.conf > $(STAGE_DIR)/$@$(PKG_DIR)/c8ydemo.conf
	@mkdir -p $(STAGE_DIR)/$@$(PREFIX)/share/doc/c8ydemo/
	@cp COPYRIGHT $(STAGE_DIR)/$@$(PREFIX)/share/doc/c8ydemo/copyright
	@cp -r pkg/$@/DEBIAN $(STAGE_DIR)/$@
	@mkdir -p $(STAGE_DIR)/$@/lib/systemd/system
	@sed 's#$$PREFIX#$(PREFIX)#g' utils/c8ydemo.service > $(STAGE_DIR)/$@/lib/systemd/system/c8ydemo.service
	@find $(STAGE_DIR)/$@ -type d | xargs chmod 755
	@fakeroot dpkg-deb --build $(STAGE_DIR)/$@ build

$(BIN_DIR)/$(BIN): $(OBJ)
	@mkdir -p $(BIN_DIR)
	@echo "(LD) $@"
	@$(CXX) $(LDFLAGS) $^ $(LDLIBS) -o $@

$(BUILD_DIR)/%.o: $(SRC_DIR)/%.cc
	@mkdir -p $(BUILD_DIR)
	@echo "(CXX) $@"
	@$(CXX) $(CPPFLAGS) $(CXXFLAGS) $< -c -o $@

$(BUILD_DIR)/%.o: $(SRC_DIR)/modbus/%.cc
	@mkdir -p $(BUILD_DIR)
	@echo "(CXX) $@"
	@$(CXX) $(CPPFLAGS) $(CXXFLAGS) $< -c -o $@

uninstall:
	@rm -f $(PREFIX)/bin/srwatchdogd $(PREFIX)/bin/$(BIN)
	@rm -rf $(PREFIX)/lib/libsera* $(PKG_DIR) /etc/c8ydemo.conf
	@rm -f /lib/systemd/system/c8ydemo.service

clean:
	@rm -rf build/* $(BIN_DIR)/$(BIN)

-include $(OBJ:.o=.d)
