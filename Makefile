# ============================================================
# Theos Makefile لبناء libTSSSDKHook.dylib
# ============================================================

LIBRARY_NAME = TSSSDKHook

TSSSDKHook_FILES = TSSSDKHook.mm fishhook.c

# أعلام C (فقط لملفات .c)
TSSSDKHook_CFLAGS = -Wno-everything

# أعلام C++ (إن وجدت ملفات .cpp)
TSSSDKHook_CCFLAGS = -std=c++17 -fno-exceptions -fno-rtti -Wno-everything

# أعلام Objective-C (إن وجدت ملفات .m)
TSSSDKHook_OBJCFLAGS = -Wno-everything

# أعلام Objective-C++ (لملفات .mm)
TSSSDKHook_OBJCCFLAGS = -std=c++17 -fno-exceptions -fno-rtti -fno-objc-arc -Wno-everything

# أعلام الربط
TSSSDKHook_LDFLAGS = -fapplication-extension

# المكتبات والأطر
TSSSDKHook_LIBRARIES = objc
TSSSDKHook_FRAMEWORKS = Foundation UIKit

# الرموز المُصدَّرة
TSSSDKHook_EXPORTED_SYMBOLS = InitializeHookSystem EnableHookSystem DisableHookSystem RestoreHookSystem GetHookStatistics

# المعماريات والإصدار
ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:12.0

# تضمين Theos
include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/library.mk
