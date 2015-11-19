BUILD:=debug
SRC_DIR:=src
BUILD_DIR:=build
SRC:=$(wildcard $(SRC_DIR)/*.cc)
OBJ:=$(addprefix $(BUILD_DIR)/,$(notdir $(SRC:.cc=.o)))

BIN_DIR:=bin
BIN:=c8ydemo-agent
CXXFLAGS+=-Wall -pedantic -Wextra -std=c++11\
		  -I$(C8Y_LIB_PATH)/include -MMD\
		  -I$(C8Y_LIB_PATH)/ext/LuaBridge/Source/LuaBridge
LDFLAGS:=-Llib
LDLIBS:=-lsera

ifeq ($(BUILD), release)
CXXFLAGS+=-O2 -DNDEBUG
LDFLAGS+=-O2 -s -flto
else
CXXFLAGS+=-O0 -g -DDEBUG
LDFLAGS+=-O0 -g
endif

.PHONY: all release clean

all: $(BIN)

release:
	make "BUILD=release"

$(BIN): $(OBJ)
	@mkdir -p $(BIN_DIR)
	$(CXX) $(LDFLAGS) $^ $(LDLIBS) -o $(BIN_DIR)/$@

$(BUILD_DIR)/%.o: $(SRC_DIR)/%.cc
	@mkdir -p $(BUILD_DIR)
	$(CXX) $(CXXFLAGS) $< -c -o $@

clean:
	@rm -f $(BUILD_DIR)/*.o $(BUILD_DIR)/*.d $(BIN_DIR)/$(BIN)

-include $(OBJ:.o=.d)
