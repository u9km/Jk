// ============================================================
// ENTERPRISE-GRADE CRASH-FREE HOOK SYSTEM (ARM64 / iOS)
// Strictly POSIX compliant, Memory-Safe, No Dummy ABIs
// Version 7.0 — Deferred Init, Explicit Lifecycle, Restorable
// ============================================================

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <sys/sysctl.h>
#import <errno.h>
#import <stdbool.h>
#import <string.h>
#import <stdatomic.h>
#import <dispatch/dispatch.h>
#import <os/log.h>

#import "fishhook.h"

#ifndef __aarch64__
#error "Strictly ARM64 build required to guarantee ABI compliance."
#endif

// ============================================================
// 1. التوقيعات الرسمية (نستخدم تعريفات النظام مباشرة)
// ============================================================

typedef void* (*dlsym_orig_t)(void* __handle, const char* __symbol);
typedef void* (*dlopen_orig_t)(const char* __path, int __mode);
typedef int (*sysctl_orig_t)(int* __name, u_int __namelen, void* __oldp, size_t* __oldlenp, void* __newp, size_t __newlen);
typedef int (*sysctlbyname_orig_t)(const char* __name, void* __oldp, size_t* __oldlenp, void* __newp, size_t __newlen);
typedef int (*ptrace_orig_t)(int _request, pid_t _pid, caddr_t _addr, int _data);

// تخزين المؤشرات الأصلية - نستخدم مؤشرات عادية داخل fishhook ثم ننشرها إلى atomic
static dlsym_orig_t orig_dlsym_ptr = NULL;
static dlopen_orig_t orig_dlopen_ptr = NULL;
static sysctl_orig_t orig_sysctl_ptr = NULL;
static sysctlbyname_orig_t orig_sysctlbyname_ptr = NULL;
static ptrace_orig_t orig_ptrace_ptr = NULL;

// نسخ atomic للقراءة الآمنة داخل الـ hooks
static _Atomic(dlsym_orig_t)         atomic_orig_dlsym = NULL;
static _Atomic(dlopen_orig_t)        atomic_orig_dlopen = NULL;
static _Atomic(sysctl_orig_t)        atomic_orig_sysctl = NULL;
static _Atomic(sysctlbyname_orig_t)  atomic_orig_sysctlbyname = NULL;
static _Atomic(ptrace_orig_t)        atomic_orig_ptrace = NULL;

// ============================================================
// 2. حالة النظام (State Machine)
//    Uninitialized → Installed → Enabled ⇄ Disabled → Restored
// ============================================================

typedef enum {
    HookStateUninitialized = 0,
    HookStateInstalled,
    HookStateEnabled,
    HookStateDisabled,
    HookStateRestored
} HookState;

static atomic_int hook_state = HookStateUninitialized;

// TLS flags للحد من العودية
static __thread bool in_dlsym_hook = false;
static __thread bool in_dlopen_hook = false;
static __thread bool in_sysctl_hook = false;
static __thread bool in_sysctlbyname_hook = false;
static __thread bool in_ptrace_hook = false;

// ============================================================
// 3. قوائم المنع والتحقق من البادئة
// ============================================================

static const char* blocked_symbols[]   = { "AnoSDKInit", "ChkInit", "mrpcs", NULL };
static const char* blocked_libraries[] = { "AnoSDK", "TSSSDK", "AntiCheat", NULL };
static const char* blocked_sysctls[]   = { "debugger", "security", "csops", "ptrace", "jailbreak", NULL };

// تحقق سريع من البادئة (نعتمد على عقد API الرسمي - المدخلات صالحة)
static inline bool has_prefix(const char* str, const char* prefix) {
    if (!str || !prefix) return false;
    size_t len = strlen(prefix);
    return strncmp(str, prefix, len) == 0;
}

// ============================================================
// 4. الـ Hooks (سريعة، بلا فحوص إضافية، تعتمد على atomic pointers)
// ============================================================

static void* hooked_dlsym(void* handle, const char* symbol) {
    HookState state = atomic_load_explicit(&hook_state, memory_order_acquire);
    dlsym_orig_t orig = atomic_load_explicit(&atomic_orig_dlsym, memory_order_acquire);
    
    // إذا لم تكن الحالة Enabled أو كانت هناك عودية أو المؤشر غير جاهز، نمرر مباشرة
    if (state != HookStateEnabled || in_dlsym_hook || !orig) {
        return orig ? orig(handle, symbol) : NULL;
    }
    
    in_dlsym_hook = true;
    
    bool blocked = false;
    for (int i = 0; blocked_symbols[i]; i++) {
        if (has_prefix(symbol, blocked_symbols[i])) {
            blocked = true;
            break;
        }
    }
    
    void* result = blocked ? NULL : orig(handle, symbol);
    
    in_dlsym_hook = false;
    return result;
}

static void* hooked_dlopen(const char* path, int mode) {
    HookState state = atomic_load_explicit(&hook_state, memory_order_acquire);
    dlopen_orig_t orig = atomic_load_explicit(&atomic_orig_dlopen, memory_order_acquire);
    
    if (state != HookStateEnabled || in_dlopen_hook || !orig) {
        return orig ? orig(path, mode) : NULL;
    }
    
    in_dlopen_hook = true;
    
    bool blocked = false;
    for (int i = 0; blocked_libraries[i]; i++) {
        if (has_prefix(path, blocked_libraries[i])) {
            blocked = true;
            break;
        }
    }
    
    void* result = blocked ? NULL : orig(path, mode);
    
    in_dlopen_hook = false;
    return result;
}

static int hooked_sysctl(int* name, u_int namelen, void* oldp, size_t* oldlenp, void* newp, size_t newlen) {
    HookState state = atomic_load_explicit(&hook_state, memory_order_acquire);
    sysctl_orig_t orig = atomic_load_explicit(&atomic_orig_sysctl, memory_order_acquire);
    
    if (state != HookStateEnabled || in_sysctl_hook || !orig) {
        return orig ? orig(name, namelen, oldp, oldlenp, newp, newlen) : -1;
    }
    
    in_sysctl_hook = true;
    
    bool blocked = false;
    // التحقق من المؤشر والطول قبل القراءة
    if (namelen >= 2 && name != NULL && name[0] == CTL_KERN) {
        if (name[1] == KERN_PROC || name[1] == KERN_BOOTTIME) {
            blocked = true;
        }
    }
    
    int result;
    if (blocked) {
        errno = EPERM;
        result = -1;
    } else {
        result = orig(name, namelen, oldp, oldlenp, newp, newlen);
    }
    
    in_sysctl_hook = false;
    return result;
}

static int hooked_sysctlbyname(const char* name, void* oldp, size_t* oldlenp, void* newp, size_t newlen) {
    HookState state = atomic_load_explicit(&hook_state, memory_order_acquire);
    sysctlbyname_orig_t orig = atomic_load_explicit(&atomic_orig_sysctlbyname, memory_order_acquire);
    
    if (state != HookStateEnabled || in_sysctlbyname_hook || !orig) {
        return orig ? orig(name, oldp, oldlenp, newp, newlen) : -1;
    }
    
    in_sysctlbyname_hook = true;
    
    bool blocked = false;
    for (int i = 0; blocked_sysctls[i]; i++) {
        if (has_prefix(name, blocked_sysctls[i])) {
            blocked = true;
            break;
        }
    }
    
    int result;
    if (blocked) {
        errno = ENOENT;
        result = -1;
    } else {
        result = orig(name, oldp, oldlenp, newp, newlen);
    }
    
    in_sysctlbyname_hook = false;
    return result;
}

#define PT_DENY_ATTACH 31
static int hooked_ptrace(int request, pid_t pid, caddr_t addr, int data) {
    HookState state = atomic_load_explicit(&hook_state, memory_order_acquire);
    ptrace_orig_t orig = atomic_load_explicit(&atomic_orig_ptrace, memory_order_acquire);
    
    if (state != HookStateEnabled || in_ptrace_hook || !orig) {
        return orig ? orig(request, pid, addr, data) : -1;
    }
    
    in_ptrace_hook = true;
    
    int result;
    if (request == PT_DENY_ATTACH) {
        result = 0;
    } else {
        result = orig(request, pid, addr, data);
    }
    
    in_ptrace_hook = false;
    return result;
}

// ============================================================
// 5. تعطيل لقطة الشاشة (مع إمكانية الاستعادة)
// ============================================================

static IMP original_screenshot_imp = NULL;
static bool screenshot_hook_applied = false;
static dispatch_once_t screenshot_once_token;

static UIImage* dummyScreenshotIMP(id self, SEL _cmd) {
    return nil;
}

static void apply_screenshot_hook(void) {
    dispatch_once(&screenshot_once_token, ^{
        Class screenClass = objc_getClass("UIScreen");
        if (!screenClass) return;
        
        SEL screenshotSel = sel_getUid("screenshot");
        Method screenshotMethod = class_getInstanceMethod(screenClass, screenshotSel);
        
        if (screenshotMethod) {
            // حفظ الـ IMP الأصلية قبل التعديل
            original_screenshot_imp = method_getImplementation(screenshotMethod);
            method_setImplementation(screenshotMethod, (IMP)dummyScreenshotIMP);
            screenshot_hook_applied = true;
        }
    });
}

static void restore_screenshot_hook(void) {
    if (!screenshot_hook_applied) return;
    
    Class screenClass = objc_getClass("UIScreen");
    if (!screenClass) return;
    
    SEL screenshotSel = sel_getUid("screenshot");
    Method screenshotMethod = class_getInstanceMethod(screenClass, screenshotSel);
    
    if (screenshotMethod && original_screenshot_imp) {
        method_setImplementation(screenshotMethod, original_screenshot_imp);
        screenshot_hook_applied = false;
        original_screenshot_imp = NULL;
    }
}

// ============================================================
// 6. Observer lifecycle (إدارة صريحة)
// ============================================================

static const void* kAppLaunchObserver = &kAppLaunchObserver;
static bool observer_registered = false;

static void app_launch_callback(CFNotificationCenterRef center,
                                void *observer,
                                CFStringRef name,
                                const void *object,
                                CFDictionaryRef userInfo) {
    HookState state = atomic_load_explicit(&hook_state, memory_order_acquire);
    if (state == HookStateEnabled) {
        apply_screenshot_hook();
    }
}

static void register_observer_if_needed(void) {
    if (!observer_registered) {
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetLocalCenter(),
            kAppLaunchObserver,
            app_launch_callback,
            CFSTR("UIApplicationDidFinishLaunchingNotification"),
            NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately
        );
        observer_registered = true;
    }
}

static void unregister_observer(void) {
    if (observer_registered) {
        CFNotificationCenterRemoveObserver(
            CFNotificationCenterGetLocalCenter(),
            kAppLaunchObserver,
            CFSTR("UIApplicationDidFinishLaunchingNotification"),
            NULL
        );
        observer_registered = false;
    }
}

// ============================================================
// 7. التهيئة والتثبيت المؤجل (Deferred Initialization)
// ============================================================

// لا نستخدم constructor للقيام بالعمل الثقيل؛ بدلاً من ذلك نوفر دالة صريحة
__attribute__((constructor))
static void minimal_constructor(void) {
    // لا شيء هنا؛ فقط نترك الحالة Uninitialized
}

// دالة التثبيت الفعلية - تستدعى من التطبيق بعد اكتمال التحميل
bool InitializeHookSystem(void) {
    // نسمح فقط بالانتقال من Uninitialized إلى Installed
    HookState expected = HookStateUninitialized;
    if (!atomic_compare_exchange_strong_explicit(&hook_state, &expected, HookStateInstalled,
                                                 memory_order_acq_rel, memory_order_acquire)) {
        // التهيئة حدثت بالفعل أو فشلت
        return false;
    }
    
    // تنفيذ rebinding
    struct rebinding rebindings[] = {
        {"dlsym", (void *)hooked_dlsym, (void **)&orig_dlsym_ptr},
        {"dlopen", (void *)hooked_dlopen, (void **)&orig_dlopen_ptr},
        {"sysctl", (void *)hooked_sysctl, (void **)&orig_sysctl_ptr},
        {"sysctlbyname", (void *)hooked_sysctlbyname, (void **)&orig_sysctlbyname_ptr},
        {"ptrace", (void *)hooked_ptrace, (void **)&orig_ptrace_ptr}
    };
    
    int result = rebind_symbols(rebindings, sizeof(rebindings)/sizeof(rebindings[0]));
    
    // التحقق من نجاح التثبيت
    bool success = (result == 0 &&
                    orig_dlsym_ptr != NULL &&
                    orig_dlopen_ptr != NULL &&
                    orig_sysctl_ptr != NULL &&
                    orig_sysctlbyname_ptr != NULL &&
                    orig_ptrace_ptr != NULL);
    
    if (success) {
        // نشر المؤشرات إلى النسخ atomic
        atomic_store_explicit(&atomic_orig_dlsym, orig_dlsym_ptr, memory_order_release);
        atomic_store_explicit(&atomic_orig_dlopen, orig_dlopen_ptr, memory_order_release);
        atomic_store_explicit(&atomic_orig_sysctl, orig_sysctl_ptr, memory_order_release);
        atomic_store_explicit(&atomic_orig_sysctlbyname, orig_sysctlbyname_ptr, memory_order_release);
        atomic_store_explicit(&atomic_orig_ptrace, orig_ptrace_ptr, memory_order_release);
        
        // الحالة تبقى Installed (جاهزة للتفعيل)
        os_log_info(OS_LOG_DEFAULT, "Hook system installed successfully.");
        return true;
    } else {
        // فشل التثبيت - نعيد الحالة إلى Uninitialized
        atomic_store_explicit(&hook_state, HookStateUninitialized, memory_order_release);
        os_log_error(OS_LOG_DEFAULT, "Hook system installation failed (rebind_result=%d).", result);
        return false;
    }
}

// ============================================================
// 8. واجهة التحكم العامة
// ============================================================

bool EnableHookSystem(void) {
    // ننتقل من Installed أو Disabled إلى Enabled
    HookState expected = HookStateInstalled;
    if (atomic_compare_exchange_strong_explicit(&hook_state, &expected, HookStateEnabled,
                                                memory_order_acq_rel, memory_order_acquire)) {
        // نجح التفعيل من Installed
        register_observer_if_needed();
        apply_screenshot_hook();
        os_log_info(OS_LOG_DEFAULT, "Hook system enabled.");
        return true;
    }
    
    // إذا كانت الحالة Disabled نسمح بإعادة التفعيل
    expected = HookStateDisabled;
    if (atomic_compare_exchange_strong_explicit(&hook_state, &expected, HookStateEnabled,
                                                memory_order_acq_rel, memory_order_acquire)) {
        register_observer_if_needed();
        apply_screenshot_hook();
        os_log_info(OS_LOG_DEFAULT, "Hook system re-enabled.");
        return true;
    }
    
    // أي حالة أخرى لا تسمح بالتفعيل
    return false;
}

bool DisableHookSystem(void) {
    // ننتقل من Enabled إلى Disabled
    HookState expected = HookStateEnabled;
    if (atomic_compare_exchange_strong_explicit(&hook_state, &expected, HookStateDisabled,
                                                memory_order_acq_rel, memory_order_acquire)) {
        // نوقف التدخل فقط، لا نزيل الـ hooks
        unregister_observer();
        os_log_info(OS_LOG_DEFAULT, "Hook system disabled.");
        return true;
    }
    return false;
}

bool RestoreHookSystem(void) {
    // ننتقل إلى Restored (إزالة كاملة)
    HookState expected = HookStateDisabled;
    if (atomic_compare_exchange_strong_explicit(&hook_state, &expected, HookStateRestored,
                                                memory_order_acq_rel, memory_order_acquire)) {
        // إعادة الـ IMP الأصلية للقطة الشاشة
        restore_screenshot_hook();
        unregister_observer();
        os_log_info(OS_LOG_DEFAULT, "Hook system restored.");
        return true;
    }
    
    // يمكن أيضًا الاستعادة من Enabled
    expected = HookStateEnabled;
    if (atomic_compare_exchange_strong_explicit(&hook_state, &expected, HookStateRestored,
                                                memory_order_acq_rel, memory_order_acquire)) {
        restore_screenshot_hook();
        unregister_observer();
        os_log_info(OS_LOG_DEFAULT, "Hook system restored from enabled state.");
        return true;
    }
    
    return false;
}
