// ============================================================
// ENTERPRISE-GRADE CRASH-FREE HOOK SYSTEM (ARM64 / iOS)
// Version 7.2 — With Statistics & Control API (C++17 std::atomic)
// ============================================================

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <sys/sysctl.h>
#import <errno.h>
#import <stdbool.h>
#import <string.h>
#import <atomic>
#import <dispatch/dispatch.h>
#import <os/log.h>

#import "fishhook.h"

#ifndef __aarch64__
#error "Strictly ARM64 build required to guarantee ABI compliance."
#endif

// ============================================================
// 1. التوقيعات الرسمية
// ============================================================

typedef void* (*dlsym_orig_t)(void* __handle, const char* __symbol);
typedef void* (*dlopen_orig_t)(const char* __path, int __mode);
typedef int (*sysctl_orig_t)(int* __name, u_int __namelen, void* __oldp, size_t* __oldlenp, void* __newp, size_t __newlen);
typedef int (*sysctlbyname_orig_t)(const char* __name, void* __oldp, size_t* __oldlenp, void* __newp, size_t __newlen);
typedef int (*ptrace_orig_t)(int _request, pid_t _pid, caddr_t _addr, int _data);

// تخزين المؤشرات الأصلية (غير ذرية - تستخدم فقط أثناء التهيئة)
static dlsym_orig_t orig_dlsym_ptr = NULL;
static dlopen_orig_t orig_dlopen_ptr = NULL;
static sysctl_orig_t orig_sysctl_ptr = NULL;
static sysctlbyname_orig_t orig_sysctlbyname_ptr = NULL;
static ptrace_orig_t orig_ptrace_ptr = NULL;

// نسخ atomic للقراءة الآمنة
static std::atomic<dlsym_orig_t>        atomic_orig_dlsym{nullptr};
static std::atomic<dlopen_orig_t>       atomic_orig_dlopen{nullptr};
static std::atomic<sysctl_orig_t>       atomic_orig_sysctl{nullptr};
static std::atomic<sysctlbyname_orig_t> atomic_orig_sysctlbyname{nullptr};
static std::atomic<ptrace_orig_t>       atomic_orig_ptrace{nullptr};

// ============================================================
// 2. حالة النظام
// ============================================================

typedef enum {
    HookStateUninitialized = 0,
    HookStateInstalled,
    HookStateEnabled,
    HookStateDisabled,
    HookStateRestored
} HookState;

static std::atomic<int> hook_state{HookStateUninitialized};

// TLS flags للحد من العودية
static __thread bool in_dlsym_hook = false;
static __thread bool in_dlopen_hook = false;
static __thread bool in_sysctl_hook = false;
static __thread bool in_sysctlbyname_hook = false;
static __thread bool in_ptrace_hook = false;

// ============================================================
// 3. العدادات الإحصائية (atomic)
// ============================================================

static std::atomic<int> cnt_dlsym_calls{0};
static std::atomic<int> cnt_dlsym_blocked{0};
static std::atomic<int> cnt_dlopen_calls{0};
static std::atomic<int> cnt_dlopen_blocked{0};
static std::atomic<int> cnt_sysctl_calls{0};
static std::atomic<int> cnt_sysctl_blocked{0};
static std::atomic<int> cnt_sysctlbyname_calls{0};
static std::atomic<int> cnt_sysctlbyname_blocked{0};
static std::atomic<int> cnt_ptrace_calls{0};
static std::atomic<int> cnt_ptrace_handled{0};

// ============================================================
// 4. قوائم المنع والتحقق من البادئة
// ============================================================

static const char* blocked_symbols[]   = { "AnoSDKInit", "ChkInit", "mrpcs", NULL };
static const char* blocked_libraries[] = { "AnoSDK", "TSSSDK", "AntiCheat", NULL };
static const char* blocked_sysctls[]   = { "debugger", "security", "csops", "ptrace", "jailbreak", NULL };

static inline bool has_prefix(const char* str, const char* prefix) {
    if (!str || !prefix) return false;
    size_t len = strlen(prefix);
    return strncmp(str, prefix, len) == 0;
}

// ============================================================
// 5. دوال الـ Hooks مع العدادات
// ============================================================

static void* hooked_dlsym(void* handle, const char* symbol) {
    HookState state = static_cast<HookState>(hook_state.load(std::memory_order_acquire));
    dlsym_orig_t orig = atomic_orig_dlsym.load(std::memory_order_acquire);
    
    if (state != HookStateEnabled || in_dlsym_hook || !orig) {
        return orig ? orig(handle, symbol) : NULL;
    }
    
    in_dlsym_hook = true;
    
    cnt_dlsym_calls.fetch_add(1, std::memory_order_relaxed);
    bool blocked = false;
    for (int i = 0; blocked_symbols[i]; i++) {
        if (has_prefix(symbol, blocked_symbols[i])) {
            blocked = true;
            cnt_dlsym_blocked.fetch_add(1, std::memory_order_relaxed);
            break;
        }
    }
    
    void* result = blocked ? NULL : orig(handle, symbol);
    
    in_dlsym_hook = false;
    return result;
}

static void* hooked_dlopen(const char* path, int mode) {
    HookState state = static_cast<HookState>(hook_state.load(std::memory_order_acquire));
    dlopen_orig_t orig = atomic_orig_dlopen.load(std::memory_order_acquire);
    
    if (state != HookStateEnabled || in_dlopen_hook || !orig) {
        return orig ? orig(path, mode) : NULL;
    }
    
    in_dlopen_hook = true;
    
    cnt_dlopen_calls.fetch_add(1, std::memory_order_relaxed);
    bool blocked = false;
    for (int i = 0; blocked_libraries[i]; i++) {
        if (has_prefix(path, blocked_libraries[i])) {
            blocked = true;
            cnt_dlopen_blocked.fetch_add(1, std::memory_order_relaxed);
            break;
        }
    }
    
    void* result = blocked ? NULL : orig(path, mode);
    
    in_dlopen_hook = false;
    return result;
}

static int hooked_sysctl(int* name, u_int namelen, void* oldp, size_t* oldlenp, void* newp, size_t newlen) {
    HookState state = static_cast<HookState>(hook_state.load(std::memory_order_acquire));
    sysctl_orig_t orig = atomic_orig_sysctl.load(std::memory_order_acquire);
    
    if (state != HookStateEnabled || in_sysctl_hook || !orig) {
        return orig ? orig(name, namelen, oldp, oldlenp, newp, newlen) : -1;
    }
    
    in_sysctl_hook = true;
    
    cnt_sysctl_calls.fetch_add(1, std::memory_order_relaxed);
    bool blocked = false;
    if (namelen >= 2 && name != NULL && name[0] == CTL_KERN) {
        if (name[1] == KERN_PROC || name[1] == KERN_BOOTTIME) {
            blocked = true;
            cnt_sysctl_blocked.fetch_add(1, std::memory_order_relaxed);
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
    HookState state = static_cast<HookState>(hook_state.load(std::memory_order_acquire));
    sysctlbyname_orig_t orig = atomic_orig_sysctlbyname.load(std::memory_order_acquire);
    
    if (state != HookStateEnabled || in_sysctlbyname_hook || !orig) {
        return orig ? orig(name, oldp, oldlenp, newp, newlen) : -1;
    }
    
    in_sysctlbyname_hook = true;
    
    cnt_sysctlbyname_calls.fetch_add(1, std::memory_order_relaxed);
    bool blocked = false;
    for (int i = 0; blocked_sysctls[i]; i++) {
        if (has_prefix(name, blocked_sysctls[i])) {
            blocked = true;
            cnt_sysctlbyname_blocked.fetch_add(1, std::memory_order_relaxed);
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
    HookState state = static_cast<HookState>(hook_state.load(std::memory_order_acquire));
    ptrace_orig_t orig = atomic_orig_ptrace.load(std::memory_order_acquire);
    
    if (state != HookStateEnabled || in_ptrace_hook || !orig) {
        return orig ? orig(request, pid, addr, data) : -1;
    }
    
    in_ptrace_hook = true;
    
    cnt_ptrace_calls.fetch_add(1, std::memory_order_relaxed);
    int result;
    if (request == PT_DENY_ATTACH) {
        result = 0;
        cnt_ptrace_handled.fetch_add(1, std::memory_order_relaxed);
    } else {
        result = orig(request, pid, addr, data);
    }
    
    in_ptrace_hook = false;
    return result;
}

// ============================================================
// 6. تعطيل لقطة الشاشة (مع إمكانية الاستعادة)
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
// 7. Observer lifecycle
// ============================================================

static const void* kAppLaunchObserver = &kAppLaunchObserver;
static bool observer_registered = false;

static void app_launch_callback(CFNotificationCenterRef center,
                                void *observer,
                                CFStringRef name,
                                const void *object,
                                CFDictionaryRef userInfo) {
    HookState state = static_cast<HookState>(hook_state.load(std::memory_order_acquire));
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
// 8. التهيئة والتثبيت المؤجل
// ============================================================

__attribute__((constructor))
static void minimal_constructor(void) {
    // لا شيء هنا
}

extern "C" bool InitializeHookSystem(void) {
    int expected_int = static_cast<int>(HookStateUninitialized);
    if (!hook_state.compare_exchange_strong(expected_int, static_cast<int>(HookStateInstalled),
                                            std::memory_order_acq_rel, std::memory_order_acquire)) {
        return false;
    }
    
    struct rebinding rebindings[] = {
        {"dlsym", (void *)hooked_dlsym, (void **)&orig_dlsym_ptr},
        {"dlopen", (void *)hooked_dlopen, (void **)&orig_dlopen_ptr},
        {"sysctl", (void *)hooked_sysctl, (void **)&orig_sysctl_ptr},
        {"sysctlbyname", (void *)hooked_sysctlbyname, (void **)&orig_sysctlbyname_ptr},
        {"ptrace", (void *)hooked_ptrace, (void **)&orig_ptrace_ptr}
    };
    
    int result = rebind_symbols(rebindings, sizeof(rebindings)/sizeof(rebindings[0]));
    
    bool success = (result == 0 &&
                    orig_dlsym_ptr != NULL &&
                    orig_dlopen_ptr != NULL &&
                    orig_sysctl_ptr != NULL &&
                    orig_sysctlbyname_ptr != NULL &&
                    orig_ptrace_ptr != NULL);
    
    if (success) {
        atomic_orig_dlsym.store(orig_dlsym_ptr, std::memory_order_release);
        atomic_orig_dlopen.store(orig_dlopen_ptr, std::memory_order_release);
        atomic_orig_sysctl.store(orig_sysctl_ptr, std::memory_order_release);
        atomic_orig_sysctlbyname.store(orig_sysctlbyname_ptr, std::memory_order_release);
        atomic_orig_ptrace.store(orig_ptrace_ptr, std::memory_order_release);
        
        os_log_info(OS_LOG_DEFAULT, "Hook system installed successfully.");
        return true;
    } else {
        hook_state.store(static_cast<int>(HookStateUninitialized), std::memory_order_release);
        os_log_error(OS_LOG_DEFAULT, "Hook system installation failed (rebind_result=%d).", result);
        return false;
    }
}

// ============================================================
// 9. واجهة التحكم العامة
// ============================================================

extern "C" bool EnableHookSystem(void) {
    int expected_int = static_cast<int>(HookStateInstalled);
    if (hook_state.compare_exchange_strong(expected_int, static_cast<int>(HookStateEnabled),
                                           std::memory_order_acq_rel, std::memory_order_acquire)) {
        register_observer_if_needed();
        apply_screenshot_hook();
        os_log_info(OS_LOG_DEFAULT, "Hook system enabled.");
        return true;
    }
    
    expected_int = static_cast<int>(HookStateDisabled);
    if (hook_state.compare_exchange_strong(expected_int, static_cast<int>(HookStateEnabled),
                                           std::memory_order_acq_rel, std::memory_order_acquire)) {
        register_observer_if_needed();
        apply_screenshot_hook();
        os_log_info(OS_LOG_DEFAULT, "Hook system re-enabled.");
        return true;
    }
    
    return false;
}

extern "C" bool DisableHookSystem(void) {
    int expected_int = static_cast<int>(HookStateEnabled);
    if (hook_state.compare_exchange_strong(expected_int, static_cast<int>(HookStateDisabled),
                                           std::memory_order_acq_rel, std::memory_order_acquire)) {
        unregister_observer();
        os_log_info(OS_LOG_DEFAULT, "Hook system disabled.");
        return true;
    }
    return false;
}

extern "C" bool RestoreHookSystem(void) {
    int expected_int = static_cast<int>(HookStateDisabled);
    if (hook_state.compare_exchange_strong(expected_int, static_cast<int>(HookStateRestored),
                                           std::memory_order_acq_rel, std::memory_order_acquire)) {
        restore_screenshot_hook();
        unregister_observer();
        os_log_info(OS_LOG_DEFAULT, "Hook system restored.");
        return true;
    }
    
    expected_int = static_cast<int>(HookStateEnabled);
    if (hook_state.compare_exchange_strong(expected_int, static_cast<int>(HookStateRestored),
                                           std::memory_order_acq_rel, std::memory_order_acquire)) {
        restore_screenshot_hook();
        unregister_observer();
        os_log_info(OS_LOG_DEFAULT, "Hook system restored from enabled state.");
        return true;
    }
    
    return false;
}

// ============================================================
// 10. دالة جلب الإحصائيات
// ============================================================

typedef struct {
    int total_dlsym_calls;
    int total_dlsym_blocked;
    int total_dlopen_calls;
    int total_dlopen_blocked;
    int total_sysctl_calls;
    int total_sysctl_blocked;
    int total_sysctlbyname_calls;
    int total_sysctlbyname_blocked;
    int total_ptrace_calls;
    int total_ptrace_handled;
    int screenshot_hook_active;
    int hook_state;
} HookStatistics;

extern "C" HookStatistics GetHookStatistics(void) {
    HookStatistics stats;
    stats.total_dlsym_calls = cnt_dlsym_calls.load(std::memory_order_relaxed);
    stats.total_dlsym_blocked = cnt_dlsym_blocked.load(std::memory_order_relaxed);
    stats.total_dlopen_calls = cnt_dlopen_calls.load(std::memory_order_relaxed);
    stats.total_dlopen_blocked = cnt_dlopen_blocked.load(std::memory_order_relaxed);
    stats.total_sysctl_calls = cnt_sysctl_calls.load(std::memory_order_relaxed);
    stats.total_sysctl_blocked = cnt_sysctl_blocked.load(std::memory_order_relaxed);
    stats.total_sysctlbyname_calls = cnt_sysctlbyname_calls.load(std::memory_order_relaxed);
    stats.total_sysctlbyname_blocked = cnt_sysctlbyname_blocked.load(std::memory_order_relaxed);
    stats.total_ptrace_calls = cnt_ptrace_calls.load(std::memory_order_relaxed);
    stats.total_ptrace_handled = cnt_ptrace_handled.load(std::memory_order_relaxed);
    stats.screenshot_hook_active = screenshot_hook_applied ? 1 : 0;
    stats.hook_state = hook_state.load(std::memory_order_relaxed);
    return stats;
}
