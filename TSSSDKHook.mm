// ============================================================
// HOOK SYSTEM FOR NON-JAILBROKEN iOS (Secure, Crash-Free, Pure C core)
// ============================================================

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>
#import <mach/mach.h>
#import <sys/sysctl.h>
#import <mach-o/dyld.h>
#import <mach-o/getsect.h>
#import <errno.h> // لحل مشكلة إرجاع -1

#import "fishhook.h"

// ============================================================
// 1. تعريف التواقيع الأصلية
// ============================================================

typedef void* (*dlsym_orig_t)(void* handle, const char* symbol);
typedef void* (*dlopen_orig_t)(const char* path, int mode);
typedef int (*sysctl_orig_t)(int*, u_int, void*, size_t*, void*, size_t);
typedef int (*sysctlbyname_orig_t)(const char*, void*, size_t*, void*, size_t);
// استبدال syscall بـ ptrace لحل المشكلة #4 و #8
typedef int (*ptrace_orig_t)(int request, pid_t pid, caddr_t addr, int data);

static dlsym_orig_t orig_dlsym = NULL;
static dlopen_orig_t orig_dlopen = NULL;
static sysctl_orig_t orig_sysctl = NULL;
static sysctlbyname_orig_t orig_sysctlbyname = NULL;
static ptrace_orig_t orig_ptrace = NULL;

// ============================================================
// 2. قوائم الحظر (Pure C Arrays لحل المشكلة #7 و #11)
// ============================================================

static const char* blocked_symbols[] = {
    "AnoSDKInit", "AnoSDKInitEx", "AnoSDKIoctl", "AnoSDKIoctlOld",
    "ChkInit", "ChkLogout", "ChkSetGameStatus", "SetUserInfoEx",
    "mrpcs", "ms_open_file", "handler", "newStub", NULL // NULL ضروري لإنهاء اللوب
};

static const char* blocked_libraries[] = {
    "AnoSDK", "TSSSDK", "AntiCheat", "mrpcs", "ace", NULL
};

static const char* blocked_sysctls[] = {
    "debugger", "security", "csops", "ptrace", "jailbreak", NULL
};

// دالة مساعدة للبحث السريع والآمن في لغة C
static bool is_blocked(const char* target, const char** list) {
    if (!target) return false;
    for (int i = 0; list[i] != NULL; i++) {
        if (strstr(target, list[i]) != NULL) {
            return true;
        }
    }
    return false;
}

// ============================================================
// 3. دوال الاعتراض (Hooks) المحسنة
// ============================================================

static void* hooked_dlsym(void* handle, const char* symbol) {
    if (is_blocked(symbol, blocked_symbols)) {
        return NULL; // المشكلة #5: dlsym يتوقع NULL عند الفشل
    }
    return orig_dlsym ? orig_dlsym(handle, symbol) : NULL;
}

static void* hooked_dlopen(const char* path, int mode) {
    if (is_blocked(path, blocked_libraries)) {
        return NULL;
    }
    return orig_dlopen ? orig_dlopen(path, mode) : NULL;
}

static int hooked_sysctl(int* name, u_int namelen, void* oldp, size_t* oldlenp, void* newp, size_t newlen) {
    if (name != NULL && namelen >= 2 && name[0] == CTL_KERN) {
        if (name[1] == KERN_PROC || name[1] == KERN_BOOTTIME) {
            errno = ENOENT; // المشكلة #5: ضبط errno يمنع التطبيق من الانهيار عند التعامل مع -1
            return -1; 
        }
    }
    return orig_sysctl ? orig_sysctl(name, namelen, oldp, oldlenp, newp, newlen) : -1;
}

static int hooked_sysctlbyname(const char* name, void* oldp, size_t* oldlenp, void* newp, size_t newlen) {
    if (is_blocked(name, blocked_sysctls)) {
        errno = ENOENT; // إيهام النظام بأن الخاصية غير موجودة
        return -1;
    }
    return orig_sysctlbyname ? orig_sysctlbyname(name, oldp, oldlenp, newp, newlen) : -1;
}

// المشكلة #4: استخدام ptrace بدلاً من syscall الخطيرة
#define PT_DENY_ATTACH 31
static int hooked_ptrace(int request, pid_t pid, caddr_t addr, int data) {
    if (request == PT_DENY_ATTACH) {
        return 0; // المشكلة #5: إرجاع 0 يعني نجاح وهمي لمنع الانهيار
    }
    return orig_ptrace ? orig_ptrace(request, pid, addr, data) : -1;
}

// ============================================================
// 4. نظام Swizzling الآمن (لحل المشكلة #3)
// ============================================================

@interface SafeHooker : NSObject
@end

@implementation SafeHooker

// دالة Swizzling آمنة تتحقق من وجود الميثود أولاً
+ (void)safeSwizzleClass:(Class)cls original:(SEL)origSEL replacement:(SEL)newSEL {
    if (!cls) return;
    
    Method origMethod = class_getInstanceMethod(cls, origSEL);
    Method newMethod = class_getInstanceMethod(cls, newSEL);
    
    if (!origMethod || !newMethod) return; // منع الكراش إذا كان الـ API غير متوفر
    
    if (class_addMethod(cls, origSEL, method_getImplementation(newMethod), method_getTypeEncoding(newMethod))) {
        class_replaceMethod(cls, newSEL, method_getImplementation(origMethod), method_getTypeEncoding(origMethod));
    } else {
        method_exchangeImplementations(origMethod, newMethod);
    }
}

+ (void)installObjectiveCHooks {
    @autoreleasepool { // المشكلة #11: منع تسريب الذاكرة (ARC issues)
        [self safeSwizzleClass:NSClassFromString(@"UIScreen") 
                      original:NSSelectorFromString(@"screenshot") 
                   replacement:@selector(blocked_screenshot)];
    }
}

- (UIImage*)blocked_screenshot {
    return nil;
}

@end

// ============================================================
// 5. نظام التثبيت بالتوقيت الصحيح (لحل المشكلة #1، #2، #6، #10)
// ============================================================

static void InstallLowLevelHooks() {
    struct rebinding rebindings[] = {
        {"dlsym", (void *)hooked_dlsym, (void **)&orig_dlsym},
        {"dlopen", (void *)hooked_dlopen, (void **)&orig_dlopen},
        {"sysctl", (void *)hooked_sysctl, (void **)&orig_sysctl},
        {"sysctlbyname", (void *)hooked_sysctlbyname, (void **)&orig_sysctlbyname},
        {"ptrace", (void *)hooked_ptrace, (void **)&orig_ptrace}
    };
    
    // المشكلة #6: التحقق من نجاح الـ Rebinding
    int result = rebind_symbols(rebindings, sizeof(rebindings)/sizeof(rebindings[0]));
    if (result != 0) {
        // فشل التثبيت، يمكن إضافة لوج هنا
    }
}

// دالة يتم استدعاؤها عند انتهاء التطبيق من التحميل تماماً
static void AppFinishedLaunching(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    [SafeHooker installObjectiveCHooks];
}

__attribute__((constructor))
static void InitializeHooks() {
    // 1. تثبيت الـ C Hooks المنخفضة المستوى فوراً (آمنة تماماً)
    InstallLowLevelHooks();
    
    // 2. المشكلة #2 و #10: تثبيت Objective-C Hooks بعد انتهاء تحميل UIKit تماماً
    CFNotificationCenterAddObserver(CFNotificationCenterGetLocalCenter(), 
                                    NULL, 
                                    AppFinishedLaunching, 
                                    (CFStringRef)UIApplicationDidFinishLaunchingNotification, 
                                    NULL, 
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
}
