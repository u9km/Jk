# ============================================================
# Makefile متطور لبناء libTSSSDKHook.dylib
# يدعم: اكتشاف تلقائي للمصادر، بناء منفصل، أوضاع Debug/Release،
#       توقيع اختياري، معلومات تبعية تلقائية، وألوان في الإخراج.
# ============================================================

# ---------- الإعدادات العامة ----------
TARGET      := libTSSSDKHook
DYLIB       := $(TARGET).dylib
BUILD_DIR   := build
OBJ_DIR     := $(BUILD_DIR)/obj
DYLIB_DIR   := $(BUILD_DIR)/dylib
DEP_DIR     := $(BUILD_DIR)/dep

# أدوات البناء
CC          := clang
CXX         := clang++

# SDK والإعدادات
SDK_PATH    := $(shell xcrun --sdk iphoneos --show-sdk-path)
ARCH        ?= arm64
IOS_MIN     := 12.0
TARGET_TRIPLE := $(ARCH)-apple-ios$(IOS_MIN)

# أعلام مشتركة
COMMON_FLAGS := -isysroot $(SDK_PATH) \
                -miphoneos-version-min=$(IOS_MIN) \
                -target $(TARGET_TRIPLE) \
                -fno-exceptions \
                -fno-rtti

# أعلام صارمة للتحذيرات (يمكن تعطيلها عبر WARNINGS=0)
WARNINGS    ?= 1
ifeq ($(WARNINGS),1)
COMMON_FLAGS += -Wall -Wextra -Wpedantic -Wshadow -Wconversion -Wno-unused-parameter
endif

# أعلام C
CFLAGS      := -O2 -std=c99 $(COMMON_FLAGS)
# أعلام C++
CXXFLAGS    := -O2 -std=c++17 -fno-objc-arc $(COMMON_FLAGS)

# أعلام الروابط
LDFLAGS     := -dynamiclib \
               -install_name @rpath/$(DYLIB) \
               -isysroot $(SDK_PATH) \
               -miphoneos-version-min=$(IOS_MIN) \
               -target $(TARGET_TRIPLE) \
               -fapplication-extension

# المكتبات
LIBS        := -framework Foundation -framework UIKit -lobjc

# ملفات التصدير (اختياري)
EXPORT_LIST ?= exports.txt
ifneq ($(wildcard $(EXPORT_LIST)),)
LDFLAGS     += -exported_symbols_list $(EXPORT_LIST)
endif

# التوقيع (اختياري)
CODESIGN_IDENTITY ?=
ifneq ($(CODESIGN_IDENTITY),)
LDFLAGS     += -Wl,-sectcreate,__TEXT,__info_plist,Info.plist
endif

# اكتشاف تلقائي لملفات المصدر
SRCS_C      := $(wildcard *.c)
SRCS_MM     := $(wildcard *.mm)
SRCS_M      := $(wildcard *.m)
SRCS_CPP    := $(wildcard *.cpp)
SRCS        := $(SRCS_C) $(SRCS_MM) $(SRCS_M) $(SRCS_CPP)

# تحويل المصادر إلى ملفات object و dependency
OBJS        := $(patsubst %.c,$(OBJ_DIR)/%.o,$(SRCS_C))
OBJS        += $(patsubst %.mm,$(OBJ_DIR)/%.o,$(SRCS_MM))
OBJS        += $(patsubst %.m,$(OBJ_DIR)/%.o,$(SRCS_M))
OBJS        += $(patsubst %.cpp,$(OBJ_DIR)/%.o,$(SRCS_CPP))

DEPS        := $(OBJS:.o=.d)

# ألوان ANSI (تلقائياً تُعطل إذا لم يكن الطرفية تدعمها)
ifneq ($(TERM),dumb)
  COLOR_RESET   := \033[0m
  COLOR_INFO    := \033[1;34m
  COLOR_SUCCESS := \033[1;32m
  COLOR_WARNING := \033[1;33m
  COLOR_ERROR   := \033[1;31m
else
  COLOR_RESET   :=
  COLOR_INFO    :=
  COLOR_SUCCESS :=
  COLOR_WARNING :=
  COLOR_ERROR   :=
endif

# ============================================================
# الأهداف
# ============================================================

.PHONY: all clean rebuild debug release info codesign

all: $(DYLIB_DIR)/$(DYLIB)

# قاعدة ربط dylib
$(DYLIB_DIR)/$(DYLIB): $(OBJS)
	@printf "$(COLOR_INFO)=== بناء $(DYLIB) ===$(COLOR_RESET)\n"
	@mkdir -p $(DYLIB_DIR)
	$(CXX) $(LDFLAGS) $(OBJS) $(LIBS) -o $@
	@printf "$(COLOR_SUCCESS)=== تم البناء بنجاح ===$(COLOR_RESET)\n"
	@ls -lh $@
	@file $@
ifeq ($(CODESIGN_IDENTITY),)
	@printf "$(COLOR_WARNING)ملاحظة: لم يتم التوقيع. يمكنك التوقيع عبر CODESIGN_IDENTITY=...$(COLOR_RESET)\n"
else
	@codesign -s $(CODESIGN_IDENTITY) $@ || true
	@printf "$(COLOR_SUCCESS)تم التوقيع بنجاح$(COLOR_RESET)\n"
endif

# قواعد بناء ملفات object مع توليد ملفات التبعية
$(OBJ_DIR)/%.o: %.c
	@mkdir -p $(dir $@) $(DEP_DIR)
	$(CC) $(CFLAGS) -MMD -MP -MF $(DEP_DIR)/$*.d -c $< -o $@

$(OBJ_DIR)/%.o: %.mm
	@mkdir -p $(dir $@) $(DEP_DIR)
	$(CXX) $(CXXFLAGS) -x objective-c++ -MMD -MP -MF $(DEP_DIR)/$*.d -c $< -o $@

$(OBJ_DIR)/%.o: %.m
	@mkdir -p $(dir $@) $(DEP_DIR)
	$(CC) $(CFLAGS) -x objective-c -MMD -MP -MF $(DEP_DIR)/$*.d -c $< -o $@

$(OBJ_DIR)/%.o: %.cpp
	@mkdir -p $(dir $@) $(DEP_DIR)
	$(CXX) $(CXXFLAGS) -x c++ -MMD -MP -MF $(DEP_DIR)/$*.d -c $< -o $@

# تضمين ملفات التبعية (إن وجدت)
-include $(DEPS)

# تنظيف كامل
clean:
	@printf "$(COLOR_WARNING)تنظيف مجلد البناء...$(COLOR_RESET)\n"
	rm -rf $(BUILD_DIR)
	@printf "$(COLOR_SUCCESS)تم التنظيف$(COLOR_RESET)\n"

# إعادة بناء من الصفر
rebuild: clean all

# بناء بوضع التصحيح (بدون تحسين، مع رموز تصحيح، وفحص عناوين)
debug: CFLAGS   += -DDEBUG -g -O0 -fno-omit-frame-pointer
debug: CXXFLAGS += -DDEBUG -g -O0 -fno-omit-frame-pointer
debug: LDFLAGS  += -g
debug: clean all

# بناء بوضع الإصدار (تحسين عالي وتجريد)
release: CFLAGS   += -DNDEBUG -O3 -fomit-frame-pointer
release: CXXFLAGS += -DNDEBUG -O3 -fomit-frame-pointer
release: LDFLAGS  += -Wl,-dead_strip
release: clean all
	@printf "$(COLOR_INFO)تجريد الرموز...$(COLOR_RESET)\n"
	strip -x $(DYLIB_DIR)/$(DYLIB) || true

# عرض معلومات الإعدادات
info:
	@printf "$(COLOR_INFO)=== إعدادات البناء ===$(COLOR_RESET)\n"
	@printf "الهدف:           $(TARGET)\n"
	@printf "المعمارية:       $(ARCH)\n"
	@printf "SDK:             $(SDK_PATH)\n"
	@printf "الحد الأدنى iOS: $(IOS_MIN)\n"
	@printf "ملفات المصدر:    $(SRCS)\n"
	@printf "ملفات الكائن:    $(OBJS)\n"
	@printf "وضع التحذيرات:   $(WARNINGS)\n"

# توقيع dylib (يتطلب CODESIGN_IDENTITY)
codesign:
	@if [ -z "$(CODESIGN_IDENTITY)" ]; then \
		echo "يرجى تحديد هوية التوقيع: make codesign CODESIGN_IDENTITY='iPhone Developer: ...'"; \
		exit 1; \
	fi
	@codesign -f -s $(CODESIGN_IDENTITY) $(DYLIB_DIR)/$(DYLIB)
	@echo "تم التوقيع بنجاح"
