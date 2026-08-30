// ============================================================
// HOOK SYSTEM FOR NON-JAILBROKEN iOS (Secure & Crash-Free)
// Based on strings extracted from anogs.cpp
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

// تأكد من وجود هذا الملف في نفس مسار المشروع
#import "fishhook.h"

// ============================================================
// 1. تعريف التواقيع والمتغيرات الأصلية
// ============================================================

typedef void* (*dlsym_orig_t)(void* handle, const char* symbol);
typedef void* (*dlopen_orig_t)(const char* path, int mode);
typedef int (*sysctl_orig_t)(int*, u_int, void*, size_t*, void*, size_t);
typedef int (*sysctlbyname_orig_t)(const char*, void*, size_t*, void*, size_t);
typedef int (*syscall_orig_t)(int, ...);

static dlsym_orig_t orig_dlsym = NULL;
static dlopen_orig_t orig_dlopen = NULL;
static sysctl_orig_t orig_sysctl = NULL;
static sysctlbyname_orig_t orig_sysctlbyname = NULL;
static syscall_orig_t orig_syscall = NULL;

// ============================================================
// 2. قوائم الحظر المستخرجة من anogs.cpp
// ============================================================

static NSArray* blockedSymbols = @[
    // AnoSDK Functions
    @"AnoSDKInit", @"AnoSDKInitEx", @"AnoSDKIoctl", @"AnoSDKIoctlOld",
    @"AnoSDKGetReportData", @"AnoSDKGetReportData2", @"AnoSDKGetReportData3", @"AnoSDKGetReportData4",
    @"AnoSDKDelReportData", @"AnoSDKDelReportData3", @"AnoSDKDelReportData4",
    @"AnoSDKOnRecvData", @"AnoSDKOnRecvSignature",
    @"AnoSDKSetUserInfo", @"AnoSDKSetUserInfoWithLicense", @"AnoSDKRegistInfoListener",
    // TSS/ACE Functions
    @"ChkInit", @"ChkLogout", @"ChkSetGameStatus", @"SetUserInfoEx",
    // MRPCS Functions
    @"mrpcs", @"mrpcs_lib", @"ms_data_crc", @"ms_data_len", @"ms_data_mod_info",
    @"ms_open_file", @"set_inline_hook_error", @"download_data_failed",
    @"ms_scan_start", @"ms_send_start", @"ms_down_start", @"mmap_fialed",
    @"ms_mmap", @"ms_push_game", @"rule_exe_fail", @"handler", @"newStub"
];

static NSArray* blockedLibraries = @[
    @"AnoSDK", @"TSSSDK", @"Security", @"AntiCheat", @"mrpcs", @"ace"
];

static NSArray* blockedSysctlNames = @[
    @"debugger", @"security", @"csops", @"ptrace", @"jailbreak",
    @"hw.cputype", @"hw.cpusubtype", @"kern.boottime", @"kern.proc"
];

// ============================================================
// 3. دوال الاعتراض (Hooks)
// ============================================================

// Hook dlsym: منع الوصول إلى الرموز المحظورة
static void* hooked_dlsym(void* handle, const char* symbol) {
    if (symbol != NULL) {
        NSString *sym = [NSString stringWithUTF8String:symbol];
        for (NSString *block in blockedSymbols) {
            if ([sym hasPrefix:block] || [sym rangeOfString:block].location != NSNotFound) {
                NSLog(@"[Hook] 🚫 dlsym blocked: %s", symbol);
                return NULL;
            }
        }
    }
    return orig_dlsym ? orig_dlsym(handle, symbol) : NULL;
}

// Hook dlopen: منع تحميل المكتبات المحظورة
static void* hooked_dlopen(const char* path, int mode) {
    if (path != NULL) {
        NSString *pathStr = [NSString stringWithUTF8String:path];
        for (NSString *block in blockedLibraries) {
            if ([pathStr rangeOfString:block].location != NSNotFound) {
                NSLog(@"[Hook] 🚫 dlopen blocked: %s", path);
                return NULL;
            }
        }
    }
    return orig_dlopen ? orig_dlopen(path, mode) : NULL;
}

// Hook sysctl: منع استعلامات النظام الحساسة
static int hooked_sysctl(int* name, u_int namelen, void* oldp, size_t* oldlenp, void* newp, size_t newlen) {
    if (name != NULL && namelen >= 2) {
        if (name[0] == CTL_KERN) {
            if (name[1] == KERN_PROC || name[1] == KERN_BOOTTIME) {
                NSLog(@"[Hook] 🚫 sysctl KERN_PROC/KERN_BOOTTIME blocked");
                return -1;
            }
        }
    }
    return orig_sysctl ? orig_sysctl(name, namelen, oldp, oldlenp, newp, newlen) : -1;
}

// Hook sysctlbyname: منع استعلامات بأسماء محظورة
static int hooked_sysctlbyname(const char* name, void* oldp, size_t* oldlenp, void* newp, size_t newlen) {
    if (name != NULL) {
        NSString *nameStr = [NSString stringWithUTF8String:name];
        for (NSString *block in blockedSysctlNames) {
            if ([nameStr rangeOfString:block].location != NSNotFound) {
                NSLog(@"[Hook] 🚫 sysctlbyname blocked: %s", name);
                return -1;
            }
        }
    }
    return orig_sysctlbyname ? orig_sysctlbyname(name, oldp, oldlenp, newp, newlen) : -1;
}

// Hook syscall: منع استدعاءات النظام المشبوهة (مثل ptrace)
static int hooked_syscall(int number, ...) {
    // 26 هو رقم ptrace في أنظمة BSD/iOS
    if (number == 26 || number == 27) { 
        NSLog(@"[Hook] 🚫 syscall ptrace blocked");
        return 0; // إرجاع 0 (نجاح وهمي) لمنع إغلاق التطبيق
    }
    
    // استخراج الوسائط (syscall يقبل 6 وسائط كحد أقصى)
    va_list args;
    va_start(args, number);
    void *arg1 = va_arg(args, void *);
    void *arg2 = va_arg(args, void *);
    void *arg3 = va_arg(args, void *);
    void *arg4 = va_arg(args, void *);
    void *arg5 = va_arg(args, void *);
    void *arg6 = va_arg(args, void *);
    va_end(args);
    
    return orig_syscall ? orig_syscall(number, arg1, arg2, arg3, arg4, arg5, arg6) : -1;
}

// ============================================================
// 4. Method Swizzling لدوال Objective-C (مثال: UIScreen)
// ============================================================

// تمت إضافة الواجهة (Interface) لتجنب أخطاء البناء
@interface SafeSwizzler : NSObject
@end

@implementation SafeSwizzler

+ (void)load {
    // Hook screenshot
    Class screenClass = NSClassFromString(@"UIScreen");
    SEL origSEL = NSSelectorFromString(@"screenshot");
    Method origMethod = class_getInstanceMethod(screenClass, origSEL);
    if (origMethod) {
        Method swizzMethod = class_getInstanceMethod([self class], @selector(blocked_screenshot));
        if (swizzMethod) {
            method_exchangeImplementations(origMethod, swizzMethod);
            NSLog(@"[Hook] ✅ UIScreenshot swizzled");
        }
    }
}

- (UIImage*)blocked_screenshot {
    NSLog(@"[Hook] 🚫 screenshot blocked");
    return nil;
}

@end

// ============================================================
// 5. نظام التثبيت الآمن (مع تأخير)
// ============================================================

@interface HookInstaller : NSObject
@end

@implementation HookInstaller

+ (void)installHooks {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        // التحويل الصحيح (Casting) للأنواع حسب متطلبات fishhook (مهم جداً لتجاوز أخطاء البناء)
        struct rebinding rebindings[] = {
            {"dlsym", (void *)hooked_dlsym, (void **)&orig_dlsym},
            {"dlopen", (void *)hooked_dlopen, (void **)&orig_dlopen},
            {"sysctl", (void *)hooked_sysctl, (void **)&orig_sysctl},
            {"sysctlbyname", (void *)hooked_sysctlbyname, (void **)&orig_sysctlbyname},
            {"syscall", (void *)hooked_syscall, (void **)&orig_syscall}
        };
        
        rebind_symbols(rebindings, sizeof(rebindings)/sizeof(rebindings[0]));
        NSLog(@"[Hook] ✅ System hooks installed via fishhook");
        
    });
}

@end

// ============================================================
// 6. Constructor مع تأخير
// ============================================================

__attribute__((constructor))
static void InitializeHooks() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [HookInstaller installHooks];
    });
}
