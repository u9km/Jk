# ============================================================
# Makefile لبناء libTSSSDKHook.dylib
# يدعم تلقائياً ملفات: .c .mm .m .cpp
# ============================================================

TARGET := libTSSSDKHook
DYLIB := $(TARGET).dylib
BUILD_DIR := build
OBJ_DIR := $(BUILD_DIR)/obj
DYLIB_DIR := $(BUILD_DIR)/dylib

# أدوات البناء
CC := clang
CXX := clang++

# SDK والإعدادات
SDK := $(shell xcrun --sdk iphoneos --show-sdk-path)
ARCH ?= arm64
IOS_MIN := 12.0

# اكتشاف تلقائي لملفات المصدر
SRCS_C   := $(wildcard *.c)
SRCS_MM  := $(wildcard *.mm)
SRCS_M   := $(wildcard *.m)
SRCS_CPP := $(wildcard *.cpp)

# تحويل أسماء الملفات إلى ملفات object داخل OBJ_DIR
OBJS := $(patsubst %.c,$(OBJ_DIR)/%.o,$(SRCS_C))
OBJS += $(patsubst %.mm,$(OBJ_DIR)/%.o,$(SRCS_MM))
OBJS += $(patsubst %.m,$(OBJ_DIR)/%.o,$(SRCS_M))
OBJS += $(patsubst %.cpp,$(OBJ_DIR)/%.o,$(SRCS_CPP))

# إعدادات عامة
CFLAGS := -O2 -fno-exceptions -fno-rtti -isysroot $(SDK) \
          -miphoneos-version-min=$(IOS_MIN) -target $(ARCH)-apple-ios$(IOS_MIN) \
          -Wno-everything

CXXFLAGS := $(CFLAGS) -std=c++17 -fno-objc-arc

LDFLAGS := -dynamiclib -install_name @rpath/$(DYLIB) \
           -isysroot $(SDK) -miphoneos-version-min=$(IOS_MIN) \
           -target $(ARCH)-apple-ios$(IOS_MIN)

LIBS := -framework Foundation -framework UIKit -lobjc

# ============================================================
# الأهداف
# ============================================================

.PHONY: all clean debug release

all: clean $(DYLIB_DIR)/$(DYLIB)

# قواعد بناء ملفات object حسب النوع
$(OBJ_DIR)/%.o: %.c
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -std=c99 -c $< -o $@

$(OBJ_DIR)/%.o: %.mm
	@mkdir -p $(dir $@)
	$(CXX) $(CXXFLAGS) -x objective-c++ -c $< -o $@

$(OBJ_DIR)/%.o: %.m
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -x objective-c -c $< -o $@

$(OBJ_DIR)/%.o: %.cpp
	@mkdir -p $(dir $@)
	$(CXX) $(CXXFLAGS) -x c++ -c $< -o $@

# ربط جميع ملفات object في dylib
$(DYLIB_DIR)/$(DYLIB): $(OBJS)
	@echo "=== بناء $(DYLIB) ==="
	@mkdir -p $(DYLIB_DIR)
	$(CXX) $(LDFLAGS) $(OBJS) $(LIBS) -o $@
	@echo "=== تم البناء ==="
	@ls -la $@
	@file $@

# أوضاع خاصة
debug: CFLAGS += -DDEBUG -g -O0
debug: CXXFLAGS += -DDEBUG -g -O0
debug: clean $(DYLIB_DIR)/$(DYLIB)

release: CFLAGS += -DNDEBUG -O3
release: CXXFLAGS += -DNDEBUG -O3
release: clean $(DYLIB_DIR)/$(DYLIB)

clean:
	rm -rf $(BUILD_DIR)
