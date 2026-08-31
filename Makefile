# ============================================================
# Theos Makefile لبناء libTSSSDKHook.dylib
# ============================================================

# تحديد نوع المشروع: مكتبة ديناميكية
LIBRARY_NAME = TSSSDKHook

# اسم الحزمة النهائي سيكون libTSSSDKHook.dylib

# الملفات المصدرية (يتم اكتشافها تلقائياً من المجلد)
TSSSDKHook_FILES = TSSSDKHook.mm fishhook.c

# أعلام المترجم الخاصة بالمشروع
TSSSDKHook_CFLAGS = -fno-exceptions -fno-rtti -fno-objc-arc -std=c++17 -Wno-everything
TSSSDKHook_CCFLAGS = -std=c++17 -fno-exceptions -fno-rtti -fno-objc-arc -Wno-everything
TSSSDKHook_LDFLAGS = -fapplication-extension

# المكتبات المطلوبة
TSSSDKHook_LIBRARIES = objc

# الأطر المطلوبة
TSSSDKHook_FRAMEWORKS = Foundation UIKit

# تصدير الرموز المحددة فقط (اختياري)
TSSSDKHook_EXPORTED_SYMBOLS = InitializeHookSystem EnableHookSystem DisableHookSystem RestoreHookSystem GetHookStatistics

# المعماريات المدعومة
ARCHS = arm64 arm64e

# إصدار iOS الأدنى
TARGET = iphone:clang:latest:12.0

# تضمين ملفات Theos
include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/library.mk

# تنظيف إضافي
after-clean::
	rm -rf .theos
