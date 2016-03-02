BUILD:=debug
SRC_DIR:=src
BUILD_DIR:=build
SRC:=$(wildcard $(SRC_DIR)/*.cc)
OBJ:=$(addprefix $(BUILD_DIR)/,$(notdir $(SRC:.cc=.o)))

BIN_DIR:=bin
BIN:=c8ydemo-agent
CPPFLAGS+=-I$(C8Y_LIB_PATH)/include\
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

$(BIN_DIR)/$(BIN): $(OBJ)
	@mkdir -p $(BIN_DIR)
	$(CXX) $(LDFLAGS) $^ $(LDLIBS) -o $@

$(BUILD_DIR)/%.o: $(SRC_DIR)/%.cc
	@mkdir -p $(BUILD_DIR)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) $< -c -o $@

clean:
	@rm -f $(BUILD_DIR)/*.o $(BUILD_DIR)/*.d $(BIN_DIR)/$(BIN)

-include $(OBJ:.o=.d)
