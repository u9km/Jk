# ============================================================
# Makefile - TSSSDK Hook System
# متوافق مع iOS بدون جلبريك
# ============================================================

# ===== المتغيرات الأساسية =====
PROJECT_NAME := TSSSDKHook
TARGET := libTSSSDKHook
DYLIB := $(TARGET).dylib
BUILD_DIR := build
OBJ_DIR := $(BUILD_DIR)/obj
DYLIB_DIR := $(BUILD_DIR)/dylib
LOG_DIR := $(BUILD_DIR)/logs

# ===== المترجمات والأدوات =====
CXX := clang++
CC := clang
AR := ar
LD := ld
STRIP := strip
DSYMUTIL := dsymutil
LIPO := lipo
CODESIGN := codesign
INSTALL_NAME_TOOL := install_name_tool

# ===== المعماريات =====
ARCH ?= arm64
# ARCH ?= arm64e
# ARCH ?= x86_64  # للمحاكي

# ===== إصدارات iOS =====
IOS_MIN_VERSION := 12.0
SDK_VERSION := 17.0
TARGET_OS := ios

# ===== مسارات SDK =====
SDK_PATH := $(shell xcrun --sdk iphoneos --show-sdk-path)
SDK_SIM_PATH := $(shell xcrun --sdk iphonesimulator --show-sdk-path)

# ===== أعلام الترجمة =====
COMMON_FLAGS := \
    -std=c++17 \
    -O3 \
    -fvisibility=hidden \
    -fvisibility-inlines-hidden \
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
    -fstrict-aliasing \
    -fmerge-all-constants

CXXFLAGS := $(COMMON_FLAGS) \
    -isysroot $(SDK_PATH) \
    -miphoneos-version-min=$(IOS_MIN_VERSION) \
    -target $(ARCH)-apple-ios$(IOS_MIN_VERSION) \
    -Wno-everything \
    -Wno-unguarded-availability \
    -Wno-deprecated-declarations \
    -Wno-objc-property-no-attribute \
    -Wno-objc-missing-super-calls \
    -Wno-objc-designated-initializers

# ===== أعلام الربط =====
LDFLAGS := \
    -dynamiclib \
    -install_name @rpath/$(DYLIB) \
    -current_version 1.0.0 \
    -compatibility_version 1.0.0 \
    -isysroot $(SDK_PATH) \
    -miphoneos-version-min=$(IOS_MIN_VERSION) \
    -target $(ARCH)-apple-ios$(IOS_MIN_VERSION) \
    -Wl,-dead_strip \
    -Wl,-no_pie \
    -Wl,-export_dynamic \
    -Wl,-allowable_client

# ===== المكتبات =====
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

# ===== ملفات المصدر =====
SOURCES := TSSSDKHook.mm

# ===== ملفات الكائنات =====
OBJECTS := $(OBJ_DIR)/TSSSDKHook.o

# ===== الأهداف =====
.PHONY: all clean build debug release strip codesign package install uninstall verify info help

# ===== الهدف الافتراضي =====
all: clean build

# ===== البناء =====
build: $(DYLIB_DIR)/$(DYLIB)

$(DYLIB_DIR)/$(DYLIB): $(OBJECTS)
	@echo "========================================="
	@echo "🔗 ربط $(DYLIB)"
	@echo "========================================="
	@mkdir -p $(DYLIB_DIR)
	$(CXX) $(LDFLAGS) $(OBJECTS) $(LIBS) -o $@
	@echo "✅ تم البناء: $@"
	@echo "📊 الحجم: $$(du -h $@ | cut -f1)"
	@echo "🔍 النوع: $$(file $@)"
	@echo "📦 المعماريات: $$(lipo -info $@)"

$(OBJ_DIR)/%.o: %.mm
	@echo "========================================="
	@echo "🔨 ترجمة $<"
	@echo "========================================="
	@mkdir -p $(dir $@)
	$(CXX) $(CXXFLAGS) -c $< -o $@
	@echo "✅ تمت الترجمة"

# ===== وضع التصحيح =====
debug: CXXFLAGS += -DDEBUG -g -O0 -fno-inline
debug: LDFLAGS += -g
debug: clean build
	@echo "✅ تم البناء في وضع التصحيح"

# ===== وضع الإصدار =====
release: CXXFLAGS += -DNDEBUG -DRELEASE -O3 -flto
release: LDFLAGS += -O3 -flto
release: clean build strip
	@echo "✅ تم البناء في وضع الإصدار"

# ===== تجريد الرموز =====
strip: $(DYLIB_DIR)/$(DYLIB)
	@echo "========================================="
	@echo "🔪 تجريد الرموز"
	@echo "========================================="
	$(STRIP) -S -x $(DYLIB_DIR)/$(DYLIB)
	@echo "✅ تم التجريد"
	@echo "📊 الحجم بعد التجريد: $$(du -h $(DYLIB_DIR)/$(DYLIB) | cut -f1)"

# ===== إنشاء ملفات التصحيح =====
dsym: $(DYLIB_DIR)/$(DYLIB)
	@echo "========================================="
	@echo "📝 إنشاء ملفات التصحيح"
	@echo "========================================="
	$(DSYMUTIL) $(DYLIB_DIR)/$(DYLIB) -o $(DYLIB_DIR)/$(DYLIB).dSYM
	@echo "✅ تم الإنشاء"

# ===== التوقيع =====
codesign: $(DYLIB_DIR)/$(DYLIB)
	@echo "========================================="
	@echo "🔐 توقيع الكود"
	@echo "========================================="
	@if [ -z "$(IDENTITY)" ]; then \
		echo "⚠️ لم يتم تحديد هوية التوقيع"; \
		echo "استخدم: make codesign IDENTITY='Apple Development: email@example.com'"; \
	else \
		$(CODESIGN) -s "$(IDENTITY)" --force $(DYLIB_DIR)/$(DYLIB); \
		echo "✅ تم التوقيع"; \
	fi

# ===== إنشاء حزمة =====
package: build
	@echo "========================================="
	@echo "📦 إنشاء حزمة"
	@echo "========================================="
	@mkdir -p $(BUILD_DIR)/package
	@mkdir -p $(BUILD_DIR)/package/Library/MobileSubstrate/DynamicLibraries
	cp $(DYLIB_DIR)/$(DYLIB) $(BUILD_DIR)/package/Library/MobileSubstrate/DynamicLibraries/
	@echo '<?xml version="1.0" encoding="UTF-8"?>' > $(BUILD_DIR)/package/Library/MobileSubstrate/DynamicLibraries/$(TARGET).plist
	@echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' >> $(BUILD_DIR)/package/Library/MobileSubstrate/DynamicLibraries/$(TARGET).plist
	@echo '<plist version="1.0">' >> $(BUILD_DIR)/package/Library/MobileSubstrate/DynamicLibraries/$(TARGET).plist
	@echo '<dict>' >> $(BUILD_DIR)/package/Library/MobileSubstrate/DynamicLibraries/$(TARGET).plist
	@echo '    <key>Filter</key>' >> $(BUILD_DIR)/package/Library/MobileSubstrate/DynamicLibraries/$(TARGET).plist
	@echo '    <dict>' >> $(BUILD_DIR)/package/Library/MobileSubstrate/DynamicLibraries/$(TARGET).plist
	@echo '        <key>Bundles</key>' >> $(BUILD_DIR)/package/Library/MobileSubstrate/DynamicLibraries/$(TARGET).plist
	@echo '        <array>' >> $(BUILD_DIR)/package/Library/MobileSubstrate/DynamicLibraries/$(TARGET).plist
	@echo '            <string>com.tencent.ig</string>' >> $(BUILD_DIR)/package/Library/MobileSubstrate/DynamicLibraries/$(TARGET).plist
	@echo '        </array>' >> $(BUILD_DIR)/package/Library/MobileSubstrate/DynamicLibraries/$(TARGET).plist
	@echo '    </dict>' >> $(BUILD_DIR)/package/Library/MobileSubstrate/DynamicLibraries/$(TARGET).plist
	@echo '</dict>' >> $(BUILD_DIR)/package/Library/MobileSubstrate/DynamicLibraries/$(TARGET).plist
	@echo '</plist>' >> $(BUILD_DIR)/package/Library/MobileSubstrate/DynamicLibraries/$(TARGET).plist
	@echo "✅ تم إنشاء الحزمة في $(BUILD_DIR)/package/"

# ===== التثبيت (بدون جلبريك - يتطلب أدوات خاصة) =====
install: build
	@echo "========================================="
	@echo "📲 التثبيت"
	@echo "========================================="
	@echo "⚠️ التثبيت بدون جلبريك يتطلب:"
	@echo "1. Sideloadly أو AltStore"
	@echo "2. أو Xcode مع حساب مطور"
	@echo "3. أو أدوات التوقيع الذاتي"
	@echo ""
	@echo "الخطوات اليدوية:"
	@echo "1. انسخ $(DYLIB) إلى التطبيق المستهدف"
	@echo "2. عدل Info.plist للتطبيق"
	@echo "3. وقع التطبيق"
	@echo "4. ثبته على الجهاز"
	@echo "========================================="

# ===== إزالة =====
uninstall:
	@echo "========================================="
	@echo "🗑️ إزالة"
	@echo "========================================="
	rm -rf $(BUILD_DIR)
	@echo "✅ تمت الإزالة"

# ===== تنظيف =====
clean:
	@echo "========================================="
	@echo "🧹 تنظيف"
	@echo "========================================="
	rm -rf $(BUILD_DIR)
	@echo "✅ تم التنظيف"

# ===== التحقق =====
verify: $(DYLIB_DIR)/$(DYLIB)
	@echo "========================================="
	@echo "🔍 التحقق من الملف"
	@echo "========================================="
	@echo "📁 الملف: $(DYLIB_DIR)/$(DYLIB)"
	@echo "📊 الحجم: $$(du -h $(DYLIB_DIR)/$(DYLIB) | cut -f1)"
	@echo "🔍 النوع: $$(file $(DYLIB_DIR)/$(DYLIB))"
	@echo "📦 المعماريات: $$(lipo -info $(DYLIB_DIR)/$(DYLIB))"
	@echo "🔗 المكتبات:"
	@otool -L $(DYLIB_DIR)/$(DYLIB)
	@echo "========================================="

# ===== معلومات =====
info:
	@echo "========================================="
	@echo "📋 معلومات المشروع"
	@echo "========================================="
	@echo "الاسم: $(PROJECT_NAME)"
	@echo "الهدف: $(TARGET)"
	@echo "المعمارية: $(ARCH)"
	@echo "إصدار iOS: $(IOS_MIN_VERSION)"
	@echo "SDK: $(SDK_PATH)"
	@echo "========================================="
	@echo "الأوامر المتاحة:"
	@echo "  make all       - تنظيف وبناء"
	@echo "  make build     - بناء فقط"
	@echo "  make debug     - بناء debug"
	@echo "  make release   - بناء release"
	@echo "  make strip     - تجريد الرموز"
	@echo "  make dsym      - إنشاء ملفات التصحيح"
	@echo "  make codesign  - توقيع الكود"
	@echo "  make package   - إنشاء حزمة"
	@echo "  make install   - تعليمات التثبيت"
	@echo "  make verify    - التحقق من الملف"
	@echo "  make clean     - تنظيف"
	@echo "  make uninstall - إزالة كاملة"
	@echo "========================================="

# ===== مساعدة =====
help:
	@echo "========================================="
	@echo "📖 مساعدة"
	@echo "========================================="
	@echo "الاستخدام:"
	@echo "  make [الهدف] [المتغيرات]"
	@echo ""
	@echo "الأهداف:"
	@echo "  all       - تنظيف وبناء"
	@echo "  build     - بناء المشروع"
	@echo "  debug     - بناء debug"
	@echo "  release   - بناء release"
	@echo "  strip     - تجريد الرموز"
	@echo "  dsym      - ملفات التصحيح"
	@echo "  codesign  - توقيع"
	@echo "  package   - حزمة"
	@echo "  verify    - تحقق"
	@echo "  clean     - تنظيف"
	@echo ""
	@echo "المتغيرات:"
	@echo "  ARCH=arm64          - المعمارية"
	@echo "  ARCH=arm64e         - المعمارية"
	@echo "  IDENTITY='...'      - هوية التوقيع"
	@echo "========================================="
