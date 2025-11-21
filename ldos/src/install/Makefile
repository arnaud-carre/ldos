# LDOS Installer Makefile
# Cross-platform build for macOS/Linux

CXX := g++
CC := gcc
CXXFLAGS := -std=c++17 -O2 -Wall -I. -Iexternal/zopfli -Iexternal/salvador -Iexternal/salvador/libdivsufsort
CFLAGS := -std=c99 -O2 -Wall -I. -Iexternal/zopfli -Iexternal/salvador -Iexternal/salvador/libdivsufsort
LDFLAGS := -pthread -lstdc++

# Output directory
# TODO: make BINDIR configurable for different platforms
BINDIR := ../../bin/macos-arm64
TARGET := $(BINDIR)/ldos

# Source files
SOURCES := \
	ldos.cpp \
	ldosFile.cpp \
	jobSystem.cpp \
	external/zopfli/blocksplitter.c \
	external/zopfli/cache.c \
	external/zopfli/deflate.c \
	external/zopfli/gzip_container.c \
	external/zopfli/hash.c \
	external/zopfli/katajainen.c \
	external/zopfli/lz77.c \
	external/zopfli/squeeze.c \
	external/zopfli/tree.c \
	external/zopfli/util.c \
	external/zopfli/zlib_container.c \
	external/zopfli/zopfli_lib.c \
	external/salvador/matchfinder.c \
	external/salvador/shrink.c \
	external/salvador/libdivsufsort/divsufsort.c \
	external/salvador/libdivsufsort/divsufsort_utils.c \
	external/salvador/libdivsufsort/sssort.c \
	external/salvador/libdivsufsort/trsort.c

# Object files
OBJECTS := $(SOURCES:.cpp=.o)
OBJECTS := $(OBJECTS:.c=.o)

# Default target
all: $(TARGET)

# Create bin directory if it doesn't exist
$(BINDIR):
	mkdir -p $(BINDIR)

# Link
$(TARGET): $(BINDIR) $(OBJECTS)
	$(CXX) $(OBJECTS) $(LDFLAGS) -o $(TARGET)
	@echo "Build complete: $(TARGET)"

# Compile C++ files
%.o: %.cpp
	$(CXX) $(CXXFLAGS) -c $< -o $@

# Compile C files
%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

# Clean
clean:
	rm -f $(OBJECTS) $(TARGET)
	@echo "Clean complete"

# Install (copy to bin directory - already done by build)
install: all

.PHONY: all clean install
