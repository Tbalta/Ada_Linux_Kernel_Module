---
title: "Let's make a linux kernel module in Ada !"
date: 2023-07-27T21:00:00+01:00
author: "Tanguy Baltazart"
summary: "Realisation of a linux kernel module in Ada"
tags: ["language", "Ada", "Tutorial", "Linux", Kernel", Module"]
draft: true
---
# Prerequisites
- Knowledge about linux's module
- Knowledge about the Ada language
# Version
- Ubuntu 20.04.6 LTS
- Linux kernel 5.15.0
- gcc 9.4.0
- GPRBUILD Community 2019

# Introduction
Linux kernel module are typically written in C and since 2021 it is also
possible to write them in Rust.
Ada is an interesting language in this context because it is designed for safety and reliability. 
It is always a good thing to use a language that will help us avoid crash and undefined behavior.
In this tutorial we will see how to write a linux kernel module in ada.
# Theory
Since there's no support for Ada in the Linux kernel, we have to use wrappers to call our Ada code.

Interfacing Ada to C is easy with the `Pragma Export` and `Pragma Import` keyword.
```ada
-- hello_ada.ads
procedure Hello_Ada;
pragma Export (C, Hello_Ada, "hello_ada");
```
```ada
-- hello_ada.adb
with Text_IO; use Text_IO;

procedure Hello_Ada is
    -- Import the C function
    procedure Hello_C;
    pragma Import (C, Hello_C, "hello_c");
begin
    Hello_C;
    Put_Line ("Hello from Ada");
end Hello_Ada;
```
And then we can call it from C:
```c
// main.c
extern void adainit (void);
extern void adafinal (void);
extern void hello_ada(void);

void hello_c(void)
{
    printf("Hello from C\n");
}

int main(void)
{
    adainit();
    hello_ada();
    adafinal();
    return 0;
}
```
The `hello_ada` function is the one we exported from Ada.\
The `adainit` and `adafinal` functions are needed to initialize and finalize (destruct) the Ada runtime.\
It seems that the `adafinal` symbol is not always generated so we will create it as a weak symbol.
```c
// helper.c
void adafinal(void) __attribute__((weak));
void adafinal(void) {}
```

To compile this code we need to:
- Create object file for the Ada and C code.
- Create the object file containing the initialization and finalization code.
- Link all the object files together with the Ada runtime.

To create the object files we will use the `gcc` compiler.
```bash
gcc -c hello_ada.adb -o hello_ada.o
gcc -c main.c -o main.o
gcc -c helper.c -o helper.o
```
Compiling `hello_ada.adb` also creates a `hello_ada.ali` file which contains the Ada interface of the code.
We will use this file with the `gnatbind` tool to create the code for the initialisation and finalisation procedure.
```bash
# Generate the init.adb file, -n is used to indicate that the entry point is not located in ada.
gnatbind -n hello_ada.ali -o init.adb
gcc -c init.adb -o init.o
```

To build the executable, we simply link all the objects together against the Ada library.
```bash
gcc main.o helper.o hello_ada.o init.o -lgnat -o hello_ada
```

# Implementation
## The Ada runtime
In the previous example we used the standard Ada runtime. However, we cannot use it in the kernel environment.
We will build a new runtime from the existing one.

The standard runtime architecture is as follow:
```
runtime
├── build
│   ├── adainclude
│   ├── adalib
│   └── obj
└── src
```
- `adalib` directory contain the `Ada Library Information Files (.ali)` and the static library.
-  `obj` Directory contain the object files, logs and .ali files.
- `src` and `adainclude` contain the source files.

We are going to adapt the runtime present on our system to be compatible with the linux kernel.\
For this first part of the tutorial we will build the minimal viable runtime.\
We will need those files:
- `system.ads` Contain importants parameters for the runtime.
- `ada.ads` Main package that shoul be present.
- `interfac.ads` Contain useful types definition.
- `s-imgint.ad[sb]` Used for demontration purpose.

As we will not be using the standard library, we need to ensure that
`Suppress_Standard_Library` is set to `True` in `system.ads`.

## Building the runtime

To build the runtime we will use the `gprbuild` tool. So we need to create a `runtime.gpr` file.
```ada
-- runtime/runtime.gpr
-- Source: https://wiki.osdev.org/Ada_Runtime_Library
library project Runtime is
   for Create_Missing_Dirs use "True";
   for Source_Dirs use ("build/adainclude");

   --  The directory used for build artifacts.
   for Object_Dir use "build/obj";
 
   for Languages use ("Ada");
 
   package Builder is
    for Switches ("Ada") use (
        "-nostdlib",
        "-nostdinc"
      );
    for Global_Configuration_Pragmas use "runtime.adc";
   end Builder;
 
   --  For a list of all compiler switches refer to: https://gcc.gnu.org/onlinedocs/gcc-9.4.0/gnat_ugn/Alphabetical-List-of-All-Switches.html#Alphabetical-List-of-All-Switches
   package Compiler is
      for Default_Switches ("Ada") use (
        "-O0",
        "-ffunction-sections", 
        "-gnatg",
        "-fdata-sections",
        "-nostdlib",
        "-nostdinc",
        "-gnat2012",
        "-Wl,--gc-sections",
        "-fno-pie",
        "-mcmodel=kernel",
        "-g"
      );      
   end Compiler;
 
   --  We require a valid run-time library to build our run-time. 
   --  We need to ensure that the run-time we use for this purpose is built 
   --  using the same compiler and targets the same platform. A reliable way
   --  to do this is to use our run-time's sources as a run-time to build
   --  itself.
   for Library_Dir use "build/adalib";
   for Library_Kind use "static";
   for Library_Name use "gnat";
 
   for Runtime ("Ada") use "build";
 end Runtime;
```

We also need to create a `runtime.adc` file to configure global options for the runtime.\
A good place to start is the `gnat.adc` file from `Luke A. Guest`.
```ada
--                              -*- Mode: Ada -*-
--  Filename        : gnat.adc
--  Description     : Project wide pragmas and restrictions.
--  Author          : Luke A. Guest
--  Created On      : Thu Jun 14 12:04:52 2012
--  Licence         : See LICENCE in the root directory.
--  pragma Restrictions (No_Obsolescent_Features);
--  pragma Discard_Names;
--  pragma Restrictions (No_Enumeration_Maps);
pragma Normalize_Scalars;
pragma Restrictions (No_Exception_Propagation);
pragma Restrictions (No_Exception_Registration);

pragma Restrictions (No_Finalization);
pragma Restrictions (No_Tasking);
pragma Restrictions (No_Protected_Types);
pragma Restrictions (No_Delay);

pragma Restrictions (No_Allocators);
pragma Restrictions (No_Dispatch);
pragma Restrictions (No_Implicit_Dynamic_Code);

-- The following were suggested by gnatbind -r
pragma Restrictions (Simple_Barriers);
pragma Restrictions (No_Abort_Statements);
--  pragma Restrictions (No_Access_Subprograms);
pragma Restrictions (No_Asynchronous_Control); --  Ada95 only?
pragma Restrictions (No_Calendar);
pragma Restrictions (No_Default_Stream_Attributes);
pragma Restrictions (No_Dispatching_Calls);
pragma Restrictions (No_Dynamic_Attachment);
pragma Restrictions (No_Dynamic_Priorities);
pragma Restrictions (No_Entry_Calls_In_Elaboration_Code);
pragma Restrictions (No_Entry_Queue);
pragma Restrictions (No_Io);
pragma Restrictions (No_Implicit_Heap_Allocations);
pragma Restrictions (No_Initialize_Scalars);
pragma Restrictions (No_Local_Allocators);
pragma Restrictions (No_Local_Timing_Events);
pragma Restrictions (No_Local_Protected_Objects);
pragma Restrictions (No_Nested_Finalization);
pragma Restrictions (No_Protected_Type_Allocators);
pragma Restrictions (No_Relative_Delay);
pragma Restrictions (No_Requeue_Statements);
pragma Restrictions (No_Select_Statements);
pragma Restrictions (No_Specific_Termination_Handlers);
pragma Restrictions (No_Stream_Optimizations);
pragma Restrictions (No_Streams);
pragma Restrictions (No_Task_Allocators);
pragma Restrictions (No_Task_Attributes_Package);
pragma Restrictions (No_Task_Hierarchy);
pragma Restrictions (No_Task_Termination);
pragma Restrictions (No_Terminate_Alternatives);

pragma Restrictions (No_Unchecked_Deallocation);
pragma Restrictions (Static_Priorities);
pragma Restrictions (Static_Storage_Size);
pragma Restrictions (Immediate_Reclamation);

pragma Restrictions (Max_Protected_Entries => 0);
pragma Restrictions (Max_Select_Alternatives => 0);
pragma Restrictions (Max_Task_Entries => 0);
pragma Restrictions (Max_Tasks => 0);
pragma Restrictions (Max_Asynchronous_Select_Nesting => 0);

pragma Suppress (All_Checks);
```
Once those file are in place we can write the makefile for the runtime:
```makefile
RUNTIME_BINARY := ${LIB_DIR}/libgnat.a
RUNTIME_PROJ   := runtime
 
SRC_DIR        := src
BUILD_DIR      := build
LIB_DIR        := ${BUILD_DIR}/adalib
INCLUDE_DIR    := ${BUILD_DIR}/adainclude
 
SOURCE_FILES   := $(wildcard ${SRC_DIR}/*.ad?)
INCLUDE_FILES  := $(patsubst ${SRC_DIR}/%,${INCLUDE_DIR}/%,${SOURCE_FILES})
 
.PHONY: clean
 
all: ${RUNTIME_BINARY}

# Directories must be created before the run-time library can be built otherwise gprbuild will fail.
directory:
	mkdir -p ${LIB_DIR}
	mkdir -p ${INCLUDE_DIR}
	mkdir -p ${BUILD_DIR}/obj
 
clean:
	gprclean -P${RUNTIME_PROJ}
	rm -rf ${BUILD_DIR}
 
# Build the run-time library.
${RUNTIME_BINARY}: directory ${INCLUDE_FILES}
	gprbuild # -P${RUNTIME_PROJ}

# Copy the source files to the include directory.
${INCLUDE_DIR}/%: ${SRC_DIR}/%
	cp $< $@
```
The directory should now look like this:
```
runtime/
├── Makefile
├── runtime.adc
├── runtime.gpr
└── src
    ├── ada.ads
    ├── interfac.ads
    └── system.ads
```
We can compile the runtime with “make”.
# Compiling the module
We will now build a simple hello world module.
Let's begin with the C part:
```c
// src/main.c
#include <linux/module.h>

extern void adainit (void);
extern int ada_greet (void);
__init int my_init(void)
{
    adainit();
    return ada_greet();
}

extern void adafinal (void);
extern void ada_goodbye (void);
__exit void my_exit(void)
{
    ada_goodbye();
    adafinal();
}

module_init(my_init);
module_exit(my_exit);

MODULE_LICENSE("GPL v2");
```
Nothing fancy here, we just call the Ada functions `adainit`, `ada_greet`, `ada_goodbye` and `adafinal` from the C module init and exit functions.

Because `pr_info` is a macro, it doesn't have an associated symbol so it can't be imported into Ada, therefore we need to wrap it in a function.

```c
// src/helper.c
#include <linux/slab.h> // kmalloc, kfree

// pr_info is a macro, so we need to wrap it in a function
void pr_info_wrapper (const char *txt, uint32_t len)
{
    // The iso forbid variable length arrays, so we use kmalloc
    char *buff = kmalloc (len + 1, GFP_KERNEL);
    memcpy (buff, txt, len);
    // We need to add the null terminator ourselves.
    buff[len] = '\0';
    pr_info ("%s\n", buff);
    kfree (buff);
}

// adafinal symbol in case it doesn't exist
void adafinal(void)
{}
void adafinal (void) __attribute__((weak));
```

Finally, we need to write the Ada part:
```ada
-- src/greet.ads
with System;
with Interfaces;

package Greet is
    function Ada_Greet return Integer;
    pragma Export (C, Ada_Greet, "ada_greet");

    procedure Ada_Goodbye;
    pragma Export (C, Ada_Goodbye, "ada_goodbye");

    --  System.Address can be considered as a void pointer.
    --  Ada's strings aren't null terminated so we need to indicate the length.
    procedure pr_info (msg : System.Address; len : Interfaces.Integer_32);
    pragma Import (C, pr_info, "pr_info_wrapper");
end Greet;
```

```ada
-- src/greet.adb
with System;     use System;
with Interfaces; use Interfaces;

package body Greet is
    function Ada_Greet return Integer is
        str : constant String := "Hello from Ada" & Integer'Image (42);
    begin
        pr_info (str'Address, str'Length);
        return 0;
    end Ada_Greet;

    procedure Ada_Goodbye is
        str : constant String := "Goodbye from Ada";
    begin
        pr_info (str'Address, str'Length);
    end Ada_Goodbye;
end Greet;
```

Our project should look like that :
```
.
├── Makefile
├── runtime
│   ├── adalib
│   ├── build
│   │   ├── adalib
│   │   └── obj
│   ├── Makefile
│   ├── runtime.adc
│   ├── runtime.gpr
│   └── src
│       ├── ada.ads
│       ├── interfac.ads
│       └── system.ads
└── src
    ├── greet.adb
    ├── greet.ads
    ├── helper.c
    └── main.c
```
In order to compile we are going to use gprbuild once again. So let’s create the greet.gpr file.
```ada
project Greet is
   for Create_Missing_Dirs use "True";
   for Source_Dirs use ("src");

   --  The directory used for build artifacts.
   for Object_Dir use "obj";
 
   for Languages use ("Ada");
 
   package Builder is
    for Switches ("Ada") use (
        "-nostdlib",
        "-nostdinc"
      );
    for Global_Configuration_Pragmas use "ada.adc";
   end Builder;
 
   --  For a list of all compiler switches refer to: https://gcc.gnu.org/onlinedocs/gcc-9.4.0/gnat_ugn/Alphabetical-List-of-All-Switches.html#Alphabetical-List-of-All-Switches
   package Compiler is
      for Default_Switches ("Ada") use (
        "-O0",
        "-ffunction-sections", 
        "-fdata-sections",
        "-nostdlib",
        "-nostdinc",
        "-gnat2012",
        "-Wl,--gc-sections",
        "-fno-pie",
        "-mcmodel=kernel",
        "-g"
      );      
   end Compiler;
  
   for Runtime ("Ada") use "runtime/build";
 end Greet;

```
The content of the file is pretty standard we need to specify the switch for `gnatgcc` and the path to our runtime.\
Since we have compiled the runtime with the `Normalise_Scalars` pragma, we need to compile the source with this pragma as well, so we simply add this line to `ada.adc`
```ada
pragma Normalize_Scalars;
```
# Linking with KBUILD
This is the last step, we need to:
-	Create every object file needed.
-	Create and compile the elaboration procedure with `gnatbind`.
-	Linking everything accordingly



The Makefile should look like this:

```makefile
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

```

Now we can compile the project with `make` and load the module with `sudo insmod greet.ko`.
If all went well you should see the following message in the kernel log:
```
[  ] Hello from Ada 42
[  ] Goodbye from Ada
```
# References
https://docs.adacore.com/gnat_ugn-docs/html/gnat_ugn/gnat_ugn/the_gnat_compilation_model.html
https://docs.adacore.com/gnat_ugn-docs/html/gnat_ugn/gnat_ugn/building_executable_programs_with_gnat.html
https://wiki.osdev.org/Ada_Runtime_Library 
