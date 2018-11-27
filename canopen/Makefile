TARGET_NAME = c8y_canopend
CROSS   =
CC      = $(CROSS)gcc

ifeq ($(CROSS), )
CFLAGS  = -O3 -Wall
CFLAGS  = -Wall -g -DTARGET_LINUX
LDFLAGS =
endif


CO=../ext/port

OBJ_DIR = obj
CO_INC_DIR =  -I . \
	-I $(CO)/drivers/shar_inc	\
	-I $(CO)/drivers/linux		\
	-I $(CO)/canopen/include	\
	-I $(CO)/canopen/source		\


OBJECTS =   $(OBJ_DIR)/access_o.o	\
	    $(OBJ_DIR)/cmscodec.o	\
	    $(OBJ_DIR)/cmsmain.o	\
	    $(OBJ_DIR)/emerg.o	 	\
	    $(OBJ_DIR)/guard.o	 	\
	    $(OBJ_DIR)/heartbt.o	\
	    $(OBJ_DIR)/lme.o	 	\
	    $(OBJ_DIR)/nmt.o	 	\
	    $(OBJ_DIR)/nmt_s.o	 	\
	    $(OBJ_DIR)/nmt_m.o	 	\
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
	    $(OBJ_DIR)/co_debug.o	\

	 #  $(OBJ_DIR)/cpu.o		\
	 #  $(OBJ_DIR)/guard.o	 	\
	 #  $(OBJ_DIR)/sdoblock.o	\

APPLOBJECTS =  \
	    $(OBJ_DIR)/main.o	\
	    $(OBJ_DIR)/co_init.o	\
	    $(OBJ_DIR)/nmtslave.o	\
	    $(OBJ_DIR)/objects.o	\
	    $(OBJ_DIR)/usr_301.o	\




.PHONY:help all
all: lib appl

help:
	@echo "make lib		   - build libco.a"
	@echo "make appl 	   - build libco.a and s1 application objects"


VPATH=$(CO)/canopen/source

.SUFFIXES: .o
$(OBJ_DIR)/%.o : %.c  cal_conf.h
	@mkdir -p $(OBJ_DIR)
	$(CC) $(CFLAGS) $(CO_INC_DIR) -o $@ -c $<


.PHONY:lib
lib:	cal_conf.h lib/libco.a

lib/libco.a: $(OBJECTS)
	@mkdir -p lib
	ar r $@ $(OBJECTS)


$(OBJ_DIR)/init_linux.o : $(CO)/drivers/linux/init_linux.c
	$(CC) $(CFLAGS) $(DEFS) $(STFWINCLUDES) $(CO_INC_DIR) -o $@ -c $<

$(OBJ_DIR)/can_socketcan.o : $(CO)/drivers/shar_src/can_socketcan.c
	$(CC) $(CFLAGS) $(DEFS) $(STFWINCLUDES) $(CO_INC_DIR) -o $@ -c $<

$(OBJ_DIR)/cpu_linux.o : $(CO)/drivers/shar_src/cpu_linux.c
	$(CC) $(CFLAGS) $(STFWINCLUDES) $(CO_INC_DIR) -o $@ -c $<

$(OBJ_DIR)/cpu.o: $(CO)/drivers/linux/cpu.c
	$(CC) $(CFLAGS) $(DEFS) $(STFWINCLUDES) $(CO_INC_DIR)  -o $@ -c $<

$(OBJ_DIR)/cdriver.o: $(CO)/drivers/shar_src/cdriver.c
	$(CC) $(CFLAGS) $(DEFS) $(CO_INC_DIR)  -o $@ -c $<


appl: $(APPLOBJECTS) lib
	@echo "finished, now link all together"
	$(CROSS)gcc -o ../bin/$(TARGET_NAME) $(LDFLAGS) $(APPLOBJECTS) lib/libco.a

clean:
	-rm -f lib/*.a  obj/* a.out ../bin/$(TARGET_NAME)

distclean: clean
	-rm \
	generate.err co_init.c newProject_line0.eds objects.h \
	newProject_line0.txt linux_sk.can.bak


.PHONY:ctags
ctags:
	ctags *.[ch] $(VPATH)/*.[ch] \
		$(CO)/drivers/shar_src/can_socketcan.c \
		$(CO)/drivers/linux/init_linux.c \
		$(CO)/drivers/shar_src/cpu_linux.c \
		$(CO)/drivers/shar_src/can_busload.c
