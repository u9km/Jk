# ===== Makefile لبناء DYLIB بدون مكتبات خارجية =====

# المتغيرات
TARGET := libTSSSDKHook
DYLIB := $(TARGET).dylib
BUILD_DIR := build
OBJ_DIR := $(BUILD_DIR)/obj
DYLIB_DIR := $(BUILD_DIR)/dylib

# المترجم
CXX := clang++
CC := clang

# المعماريات
ARCH := arm64
# ARCH := arm64e
# ARCH := x86_64

# إصدار iOS
IOS_MIN := 12.0

# SDK
SDK := $(shell xcrun --sdk iphoneos --show-sdk-path)

# أعلام الترجمة
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
    -isysroot $(SDK) \
    -miphoneos-version-min=$(IOS_MIN) \
    -target $(ARCH)-apple-ios$(IOS_MIN) \
    -Wno-everything

# أعلام الربط
LDFLAGS := \
    -dynamiclib \
    -install_name @rpath/$(DYLIB) \
    -current_version 1.0.0 \
    -compatibility_version 1.0.0 \
    -isysroot $(SDK) \
    -miphoneos-version-min=$(IOS_MIN) \
    -target $(ARCH)-apple-ios$(IOS_MIN) \
    -Wl,-dead_strip \
    -Wl,-strip_all \
    -Wl,-no_pie

# المكتبات
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
    -framework CryptoKit \
    -framework CommonCrypto \
    -lobjc \
    -lc++ \
    -lc++abi \
    -lsystem \
    -lz \
    -lc

# ملفات المصدر
SOURCES := TSSSDKHook.mm

# الأهداف
.PHONY: all clean dylib debug release

all: clean dylib

dylib: $(DYLIB_DIR)/$(DYLIB)

$(DYLIB_DIR)/$(DYLIB): $(SOURCES)
	@echo "===== بناء $(DYLIB) ====="
	@mkdir -p $(DYLIB_DIR)
	$(CXX) $(CXXFLAGS) $(LDFLAGS) $(SOURCES) $(LIBS) -o $@
	@echo "===== تجريد الرموز ====="
	strip -S -x $@
	@echo "===== إنشاء ملفات التصحيح ====="
	dsymutil $@ -o $@.dSYM
	@echo "===== تم البناء ====="
	@echo "===== معلومات الملف ====="
	@echo "الحجم: $$(du -h $@ | cut -f1)"
	@echo "النوع: $$(file $@)"
	@echo "المعماريات: $$(lipo -info $@)"
	@echo "===== اكتمل ====="

debug: CXXFLAGS += -DDEBUG -g -O0
debug: LDFLAGS += -g
debug: clean dylib

release: CXXFLAGS += -DNDEBUG -DRELEASE -O3
release: LDFLAGS += -O3
release: clean dylib

clean:
	@echo "===== تنظيف ====="
	rm -rf $(BUILD_DIR)
	@echo "===== تم التنظيف ====="
