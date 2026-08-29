TARGET := libTSSSDKHook
DYLIB := $(TARGET).dylib
BUILD_DIR := build
DYLIB_DIR := $(BUILD_DIR)/dylib

CXX := clang++
SDK := $(shell xcrun --sdk iphoneos --show-sdk-path)
ARCH := arm64
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

.PHONY: all clean

all: clean $(DYLIB_DIR)/$(DYLIB)

$(DYLIB_DIR)/$(DYLIB): TSSSDKHook.mm
	@mkdir -p $(DYLIB_DIR)
	$(CXX) $(CXXFLAGS) $(LDFLAGS) $< $(LIBS) -o $@
	@echo "✅ تم البناء: $@"

clean:
	rm -rf $(BUILD_DIR)
