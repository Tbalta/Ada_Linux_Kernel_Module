KDIR := "/usr/src/linux-headers-$(shell uname -r)"
PWD := "$(shell pwd)"

OBJDIR := obj
SRCDIR := src

# Ada files to be compiled
ADA_FILES := $(wildcard src/*.adb)
ALI_FILES := $(patsubst src/%.adb,$(OBJDIR)/%.ali,$(ADA_FILES))
ADA_OBJS := $(patsubst src/%.adb,$(OBJDIR)/%.o,$(ADA_FILES))
LIBGNAT := runtime/build/adalib/libgnat.a

# Name of the module
obj-m += greet.o 

# Object files to be linked with the module, Variables are not supported here.
greet-objs := src/main.o src/helper.o obj/greet.o obj/init.o obj/gnat.o
.PHONY: clean runtime

all: modules

# Object file containing adainit and adafinal
obj/init.o: $(ALI_FILES)
    # Here --RTS is used to specify the path to the runtime
	gnatbind -n -o init.adb  --RTS=runtime/build $(ALI_FILES)
	gcc -c -o obj/init.o init.adb

# Easiest way to link with the static library is to rename it as an object file
obj/gnat.o: $(LIBGNAT) $(ALI_FILES)
	cp  $(LIBGNAT) obj/gnat.o

runtime:
	$(MAKE) -C runtime

$(ADA_OBJS) $(ALI_FILES) $(LIBGNAT): runtime
	gprbuild

# KBUILD require a .cmd file for each object file
%.cmd:
	touch $@

modules: $(ADA_OBJS) obj/init.o obj/gnat.o
	make -C $(KDIR) M=$(PWD) $@

modules_install: $(ADA_OBJS) obj/init.o obj/gnat.o
	make -C $(KDIR) M=$(PWD) $@

clean:
	make -C $(KDIR) M=$(PWD) $@
	${RM} init.adb init.ads
	${RM} -r $(OBJDIR)
	${MAKE} -C runtime clean