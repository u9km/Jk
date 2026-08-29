# ===== Makefile لبناء DYLIB بدون مكتبات خارجية =====

TARGET := libTSSSDKHook
DYLIB := $(TARGET).dylib
BUILD_DIR := build
OBJ_DIR := $(BUILD_DIR)/obj
DYLIB_DIR := $(BUILD_DIR)/dylib

CXX := clang++
CC := clang
STRIP := strip
DSYMUTIL := dsymutil
LIPO := lipo

ARCH := arm64
IOS_MIN := 12.0
SDK := $(shell xcrun --sdk iphoneos --show-sdk-path)

# إضافة include لـ mach-o
INCLUDES := \
    -I$(SDK)/usr/include \
    -I$(SDK)/usr/include/mach-o \
    -I$(SDK)/System/Library/Frameworks/Foundation.framework/Headers \
    -I$(SDK)/System/Library/Frameworks/UIKit.framework/Headers

CXXFLAGS := \
    -std=c++17 \
    -O2 \
    -fvisibility=hidden \
    -fno-exceptions \
    -fno-rtti \
    -fno-objc-arc \
    -fno-stack-protector \
    -fno-builtin \
    -fno-common \
    -fno-threadsafe-statics \
    -fno-use-cxa-atexit \
    -fno-unwind-tables \
    -fno-asynchronous-unwind-tables \
    -fomit-frame-pointer \
    -ffunction-sections \
    -fdata-sections \
    $(INCLUDES) \
    -isysroot $(SDK) \
    -miphoneos-version-min=$(IOS_MIN) \
    -target $(ARCH)-apple-ios$(IOS_MIN) \
    -Wno-everything \
    -Wno-unguarded-availability

LDFLAGS := \
    -dynamiclib \
    -install_name @rpath/$(DYLIB) \
    -current_version 1.0.0 \
    -compatibility_version 1.0.0 \
    -isysroot $(SDK) \
    -miphoneos-version-min=$(IOS_MIN) \
    -target $(ARCH)-apple-ios$(IOS_MIN) \
    -Wl,-dead_strip \
    -Wl,-no_pie \
    -Wl,-allowable_client \
    -Wl,-export_dynamic

# المكتبات الأساسية فقط
LIBS := \
    -framework Foundation \
    -framework UIKit \
    -framework Security \
    -framework CoreFoundation \
    -framework CFNetwork \
    -framework SystemConfiguration \
    -framework MobileCoreServices \
    -framework LocalAuthentication \
    -framework DeviceCheck \
    -lobjc \
    -lsystem \
    -lz \
    -lc

SOURCES := TSSSDKHook.mm

.PHONY: all clean dylib debug release strip info

all: clean dylib

dylib: $(DYLIB_DIR)/$(DYLIB)

$(DYLIB_DIR)/$(DYLIB): $(SOURCES)
	@echo "===== بناء $(DYLIB) ====="
	@mkdir -p $(DYLIB_DIR)
	$(CXX) $(CXXFLAGS) $(LDFLAGS) $(SOURCES) $(LIBS) -o $@
	@echo "===== تم البناء ====="
	@echo "الحجم: $$(du -h $@ | cut -f1)"
	@echo "النوع: $$(file $@)"
	@echo "المعماريات: $$(lipo -info $@)"

strip: $(DYLIB_DIR)/$(DYLIB)
	@echo "===== تجريد الرموز ====="
	$(STRIP) -S -x $(DYLIB_DIR)/$(DYLIB)
	@echo "===== إنشاء ملفات التصحيح ====="
	$(DSYMUTIL) $(DYLIB_DIR)/$(DYLIB) -o $(DYLIB_DIR)/$(DYLIB).dSYM
	@echo "===== تم التجريد ====="
	@echo "الحجم بعد التجريد: $$(du -h $(DYLIB_DIR)/$(DYLIB) | cut -f1)"

debug: CXXFLAGS += -DDEBUG -g -O0
debug: LDFLAGS += -g
debug: clean dylib
	@echo "===== وضع التصحيح: بدون تجريد ====="

release: CXXFLAGS += -DNDEBUG -DRELEASE -O3
release: LDFLAGS += -O3
release: clean dylib strip
	@echo "===== وضع الإصدار: تم التجريد ====="

clean:
	@echo "===== تنظيف ====="
	rm -rf $(BUILD_DIR)
	@echo "===== تم التنظيف ====="

info:
	@echo "===== معلومات ====="
	@echo "الهدف: $(TARGET)"
	@echo "المعمارية: $(ARCH)"
	@echo "SDK: $(SDK)"
	@echo "إصدار iOS: $(IOS_MIN)"
	@echo "===== نهاية ====="
