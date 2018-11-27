VERSION=1.0
CO_PATH=../../ext/port
TARGET_NAME = c8y_canopen_simulator

CROSS   =
#-----------------------------
CC      = $(CROSS)gcc


# use this for compiling for PC Linux
#############################################################################
ifeq ($(CROSS), )
CFLAGS  = -O3 -Wall -DTARGET_LINUX -DUSE_WRITE_TO_SYS
LDFLAGS =
endif

OBJ_DIR = obj
CO_INC_DIR =  -I . \
	-I $(CO_PATH)/drivers/shar_inc	\
	-I $(CO_PATH)/drivers/linux		\
	-I $(CO_PATH)/canopen/include	\
	-I $(CO_PATH)/canopen/source		\


OBJECTS =   $(OBJ_DIR)/access_o.o	\
	    $(OBJ_DIR)/cmscodec.o	\
	    $(OBJ_DIR)/cmsmain.o	\
	    $(OBJ_DIR)/emerg.o	 	\
	    $(OBJ_DIR)/heartbt.o	\
	    $(OBJ_DIR)/lme.o	 	\
	    $(OBJ_DIR)/nmt.o	 	\
	    $(OBJ_DIR)/nmt_s.o	 	\
	    $(OBJ_DIR)/nmterr.o	 	\
	    $(OBJ_DIR)/pdo.o	 	\
	    $(OBJ_DIR)/sdo.o	 	\
	    $(OBJ_DIR)/sdoclien.o	\
	    $(OBJ_DIR)/sdomain.o	\
	    $(OBJ_DIR)/sdoserv.o	\
	    $(OBJ_DIR)/set_com.o	\
	    $(OBJ_DIR)/slave_ut.o	\
	    $(OBJ_DIR)/timer.o		\
	    $(OBJ_DIR)/utility.o	\
	    \
	    $(OBJ_DIR)/cpu_linux.o	\
	    $(OBJ_DIR)/init_linux.o	\
	    $(OBJ_DIR)/can_socketcan.o	\
	    $(OBJ_DIR)/cdriver.o	\

	 #  $(OBJ_DIR)/cpu.o		\
	 #  $(OBJ_DIR)/guard.o	 	\
	 #  $(OBJ_DIR)/sdoblock.o	\

APPLOBJECTS =   $(OBJ_DIR)/access_o.o	\
	    $(OBJ_DIR)/main.o	\
	    $(OBJ_DIR)/appl.o	\
	    $(OBJ_DIR)/co_init.o	\
	    $(OBJ_DIR)/nmtslave.o	\
	    $(OBJ_DIR)/objects.o	\
	    $(OBJ_DIR)/usr_301.o	\

.PHONY: all
all: lib appl

VPATH=$(CO_PATH)/canopen/source

.SUFFIXES: .o
$(OBJ_DIR)/%.o : %.c  cal_conf.h
	@mkdir -p $(OBJ_DIR)
	$(CC) $(CFLAGS) $(CO_INC_DIR) -o $@ -c $<

# build the CANopen static library using the CANopen sources
.PHONY:lib
lib:	cal_conf.h lib/libco.a

lib/libco.a:	$(OBJECTS)
	@mkdir -p lib
	ar r $@ $(OBJECTS)


# CANopen driver package
$(OBJ_DIR)/init_linux.o : $(CO_PATH)/drivers/linux/init_linux.c
	$(CC) $(CFLAGS) $(DEFS) $(STFWINCLUDES) $(CO_INC_DIR) -o $@ -c $<

$(OBJ_DIR)/can_socketcan.o : $(CO_PATH)/drivers/shar_src/can_socketcan.c
	$(CC) $(CFLAGS) $(DEFS) $(STFWINCLUDES) $(CO_INC_DIR) -o $@ -c $<

$(OBJ_DIR)/cpu_linux.o : $(CO_PATH)/drivers/shar_src/cpu_linux.c
	$(CC) $(CFLAGS) $(STFWINCLUDES) $(CO_INC_DIR) -o $@ -c $<

$(OBJ_DIR)/cpu.o: $(CO_PATH)/drivers/linux/cpu.c
	$(CC) $(CFLAGS) $(DEFS) $(STFWINCLUDES) $(CO_INC_DIR)  -o $@ -c $<

$(OBJ_DIR)/cdriver.o: $(CO_PATH)/drivers/shar_src/cdriver.c
	$(CC) $(CFLAGS) $(DEFS) $(CO_INC_DIR)  -o $@ -c $<


# put all together
appl:	$(APPLOBJECTS) lib
	@echo "finished, now link all together"
	$(CROSS)gcc -o $(TARGET_NAME) $(LDFLAGS) $(APPLOBJECTS) lib/libco.a

clean:
	-rm -f lib/*.a  obj/* a.out $(TARGET_NAME)

distclean: clean
	-rm \
	generate.err co_init.c newProject_line0.eds objects.h \
	newProject_line0.txt linux_sk.can.bak


.PHONY:ctags
ctags:
	ctags *.[ch] $(VPATH)/*.[ch] \
		$(CO_PATH)/drivers/shar_src/can_socketcan.c \
		$(CO_PATH)/drivers/linux/init_linux.c \
		$(CO_PATH)/drivers/shar_src/cpu_linux.c
