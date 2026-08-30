# ===== Makefile مبسط =====
TARGET := libTSSSDKHook
DYLIB := $(TARGET).dylib
BUILD_DIR := build
DYLIB_DIR := $(BUILD_DIR)/dylib

CXX := clang++
SDK := $(shell xcrun --sdk iphoneos --show-sdk-path)
ARCH ?= arm64
IOS_MIN := 12.0

CXXFLAGS := \
    -std=c++17 \
    -O2 \
    -fno-exceptions \
    -fno-rtti \
    -fno-objc-arc \
    -isysroot $(SDK) \
    -miphoneos-version-min=$(IOS_MIN) \
    -target $(ARCH)-apple-ios$(IOS_MIN) \
    -Wno-everything

LDFLAGS := \
    -dynamiclib \
    -install_name @rpath/$(DYLIB) \
    -isysroot $(SDK) \
    -miphoneos-version-min=$(IOS_MIN) \
    -target $(ARCH)-apple-ios$(IOS_MIN)

LIBS := \
    -framework Foundation \
    -framework UIKit \
    -lobjc

.PHONY: all clean debug release

all: clean $(DYLIB_DIR)/$(DYLIB)

$(DYLIB_DIR)/$(DYLIB): TSSSDKHook.mm
	@echo "=== بناء $(DYLIB) ==="
	@mkdir -p $(DYLIB_DIR)
	$(CXX) $(CXXFLAGS) $(LDFLAGS) $< $(LIBS) -o $@
	@echo "=== تم البناء ==="
	@ls -la $@
	@file $@

debug: CXXFLAGS += -DDEBUG -g -O0
debug: clean $(DYLIB_DIR)/$(DYLIB)

release: CXXFLAGS += -DNDEBUG -O3
release: clean $(DYLIB_DIR)/$(DYLIB)

clean:
	rm -rf $(BUILD_DIR)
