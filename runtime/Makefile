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