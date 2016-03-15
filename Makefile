BUILD:=debug
SRC_DIR:=src
BUILD_DIR:=build/obj
SRC:=$(wildcard $(SRC_DIR)/*.cc)
OBJ:=$(addprefix $(BUILD_DIR)/,$(notdir $(SRC:.cc=.o)))

ifeq ($(PREFIX),)
PREFIX:=/usr
endif
BIN_DIR:=bin
STAGE_DIR:=build/staging
PKG_DIR:=$(PREFIX)/share/c8ydemo
BIN:=c8ydemo-agent
CPPFLAGS+=-I$(C8Y_LIB_PATH)/include $(shell pkg-config --cflags lua)\
		  -I$(C8Y_LIB_PATH)/ext/LuaBridge/Source/LuaBridge
CXXFLAGS+=-Wall -pedantic -Wextra -std=c++11 -MMD
LDFLAGS:=-Llib
LDLIBS:=-lsera $(shell pkg-config --libs lua)

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
	make "BUILD=release"

install: $(BIN_DIR)/$(BIN)
	@mkdir -p $(PREFIX)/bin
	@cp $(BIN_DIR)/$(BIN) $(BIN_DIR)/srwatchdogd $(PREFIX)/bin
	@cp -rP lib/ $(PREFIX)
	@mkdir -p $(PKG_DIR)
	@cp -rP lua c8ydemo.conf srtemplate.txt COPYRIGHT $(PKG_DIR)
	@cp c8ydemo.conf /etc

debian: $(BIN_DIR)/$(BIN)
	@mkdir -p $(STAGE_DIR)/$@$(PREFIX)/bin
	@cp $(BIN_DIR)/$(BIN) $(BIN_DIR)/srwatchdogd $(STAGE_DIR)/$@$(PREFIX)/bin
	@mkdir -p $(STAGE_DIR)/$@$(PREFIX)/lib
	@cp -P lib/libsera.so.1* $(STAGE_DIR)/$@$(PREFIX)/lib
	@chmod -x $(STAGE_DIR)/$@$(PREFIX)/lib/*
	@mkdir -p $(STAGE_DIR)/$@$(PKG_DIR)
	@cp -rP lua c8ydemo.conf srtemplate.txt $(STAGE_DIR)/$@$(PKG_DIR)
	@mkdir -p $(STAGE_DIR)/$@/etc
	@cp c8ydemo.conf $(STAGE_DIR)/$@/etc
	@mkdir -p $(STAGE_DIR)/$@$(PREFIX)/share/doc/c8ydemo/
	@cp COPYRIGHT $(STAGE_DIR)/$@$(PREFIX)/share/doc/c8ydemo/copyright
	@cp -r pkg/$@/DEBIAN $(STAGE_DIR)/$@
	@find $(STAGE_DIR)/$@ -type d | xargs chmod 755
	@fakeroot dpkg-deb --build $(STAGE_DIR)/$@ build

$(BIN_DIR)/$(BIN): $(OBJ)
	@mkdir -p $(BIN_DIR)
	$(CXX) $(LDFLAGS) $^ $(LDLIBS) -o $@

$(BUILD_DIR)/%.o: $(SRC_DIR)/%.cc
	@mkdir -p $(BUILD_DIR)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) $< -c -o $@

remove:
	@rm -f $(PREFIX)/bin/srwatchdogd $(PREFIX)/bin/$(BIN)
	@rm -f $(PREFIX)/lib/libsera*
	@rm -rf $(PKG_DIR)
	@rm -f /etc/c8ydemo.conf

clean:
	@rm -rf build/* $(BIN_DIR)/$(BIN)

-include $(OBJ:.o=.d)
