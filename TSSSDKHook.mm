// ===== TSSSDK Hook - كامل مع Hooks فعلية (مصحح) =====
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>
#import <mach/mach.h>
#import <sys/sysctl.h>
#import <sys/types.h>

#include <string>
#include <vector>
#include <map>

// ===== نظام Inline Hooking حقيقي لـ ARM64 =====

// تعليمات ARM64
#define ARM64_BR_X16 0xD61F0200  // br x16
#define ARM64_LDR_X16 0x58000050  // ldr x16, #8

// دالة مساعدة لتنظيف الذاكرة المؤقتة
static void ClearCache(void* address, size_t size) {
    // استخدام __clear_cache المتوفر في المترجم
    __clear_cache((char*)address, (char*)address + size);
}

static bool WriteMemory(void* address, const void* data, size_t size) {
    if (!address || !data || size == 0) return false;
    
    mach_port_t task = mach_task_self();
    kern_return_t kr;
    
    // تغيير حماية الذاكرة للكتابة
    kr = vm_protect(task, (vm_address_t)address, size, FALSE, 
                    VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
    if (kr != KERN_SUCCESS) {
        NSLog(@"[Hook] vm_protect failed: %d", kr);
        return false;
    }
    
    // الكتابة
    memcpy(address, data, size);
    
    // تنظيف الذاكرة المؤقتة
    ClearCache(address, size);
    
    // استعادة الحماية الأصلية
    vm_protect(task, (vm_address_t)address, size, FALSE, 
               VM_PROT_READ | VM_PROT_EXECUTE);
    
    return true;
}

// تثبيت Inline Hook
static bool InstallInlineHook(void* target, void* hook, void** original) {
    if (!target || !hook) return false;
    
    // حفظ العنوان الأصلي
    *original = target;
    
    // إنشاء تعليمات القفز
    uint32_t instructions[4];
    
    // ldr x16, #8
    instructions[0] = ARM64_LDR_X16;
    
    // br x16
    instructions[1] = ARM64_BR_X16;
    
    // عنوان الـ Hook (64-bit)
    uint64_t hookAddress = (uint64_t)hook;
    instructions[2] = (uint32_t)(hookAddress & 0xFFFFFFFF);
    instructions[3] = (uint32_t)(hookAddress >> 32);
    
    // كتابة التعليمات
    return WriteMemory(target, instructions, sizeof(instructions));
}

// ===== المؤشرات الأصلية =====
static void* (*o_AnoSDKInit)(void*) = nullptr;
static void* (*o_AnoSDKInitEx)(void*, void*) = nullptr;
static void* (*o_AnoSDKIoctl)(void*, int, void*, int) = nullptr;
static void* (*o_AnoSDKIoctlOld)(void*, int, void*, int) = nullptr;
static void* (*o_AnoSDKGetReportData)(void*) = nullptr;
static void* (*o_AnoSDKGetReportData2)(void*) = nullptr;
static void* (*o_AnoSDKGetReportData3)(void*) = nullptr;
static void* (*o_AnoSDKGetReportData4)(void*) = nullptr;
static void* (*o_AnoSDKDelReportData)(void*) = nullptr;
static void* (*o_AnoSDKDelReportData3)(void*) = nullptr;
static void* (*o_AnoSDKDelReportData4)(void*) = nullptr;
static void* (*o_AnoSDKOnRecvData)(void*, int) = nullptr;
static void* (*o_AnoSDKOnRecvSignature)(void*, void*) = nullptr;
static void* (*o_AnoSDKSetUserInfo)(void*, void*) = nullptr;
static void* (*o_AnoSDKSetUserInfoWithLicense)(void*, void*, void*) = nullptr;
static void* (*o_AnoSDKRegistInfoListener)(void*, void*) = nullptr;

static int (*o_sysctl)(int*, u_int, void*, size_t*, void*, size_t) = nullptr;
static int (*o_sysctlbyname)(const char*, void*, size_t*, void*, size_t) = nullptr;

// ===== دوال الاعتراض =====
static void* Hook_AnoSDKInit(void* param1) {
    NSLog(@"[Hook] Blocked AnoSDKInit");
    return nullptr;
}

static void* Hook_AnoSDKInitEx(void* param1, void* param2) {
    NSLog(@"[Hook] Blocked AnoSDKInitEx");
    return nullptr;
}

static void* Hook_AnoSDKIoctl(void* handle, int cmd, void* data, int len) {
    NSLog(@"[Hook] Blocked AnoSDKIoctl cmd=%d", cmd);
    return nullptr;
}

static void* Hook_AnoSDKIoctlOld(void* handle, int cmd, void* data, int len) {
    NSLog(@"[Hook] Blocked AnoSDKIoctlOld cmd=%d", cmd);
    return nullptr;
}

static void* Hook_AnoSDKGetReportData(void* param) {
    NSLog(@"[Hook] Blocked AnoSDKGetReportData");
    return nullptr;
}

static void* Hook_AnoSDKGetReportData2(void* param) {
    NSLog(@"[Hook] Blocked AnoSDKGetReportData2");
    return nullptr;
}

static void* Hook_AnoSDKGetReportData3(void* param) {
    NSLog(@"[Hook] Blocked AnoSDKGetReportData3");
    return nullptr;
}

static void* Hook_AnoSDKGetReportData4(void* param) {
    NSLog(@"[Hook] Blocked AnoSDKGetReportData4");
    return nullptr;
}

static void* Hook_AnoSDKDelReportData(void* param) {
    NSLog(@"[Hook] Blocked AnoSDKDelReportData");
    return nullptr;
}

static void* Hook_AnoSDKDelReportData3(void* param) {
    NSLog(@"[Hook] Blocked AnoSDKDelReportData3");
    return nullptr;
}

static void* Hook_AnoSDKDelReportData4(void* param) {
    NSLog(@"[Hook] Blocked AnoSDKDelReportData4");
    return nullptr;
}

static void* Hook_AnoSDKOnRecvData(void* data, int len) {
    NSLog(@"[Hook] Blocked AnoSDKOnRecvData len=%d", len);
    return nullptr;
}

static void* Hook_AnoSDKOnRecvSignature(void* param1, void* param2) {
    NSLog(@"[Hook] Blocked AnoSDKOnRecvSignature");
    return nullptr;
}

static void* Hook_AnoSDKSetUserInfo(void* param1, void* param2) {
    NSLog(@"[Hook] Blocked AnoSDKSetUserInfo");
    return nullptr;
}

static void* Hook_AnoSDKSetUserInfoWithLicense(void* param1, void* param2, void* param3) {
    NSLog(@"[Hook] Blocked AnoSDKSetUserInfoWithLicense");
    return nullptr;
}

static void* Hook_AnoSDKRegistInfoListener(void* param1, void* param2) {
    NSLog(@"[Hook] Blocked AnoSDKRegistInfoListener");
    return nullptr;
}

static int Hook_sysctl(int* name, u_int namelen, void* oldp, size_t* oldlenp, void* newp, size_t newlen) {
    if (name && namelen >= 2 && name[0] == CTL_KERN && name[1] == KERN_PROC) {
        NSLog(@"[Hook] Blocked sysctl KERN_PROC");
        return -1;
    }
    return o_sysctl ? o_sysctl(name, namelen, oldp, oldlenp, newp, newlen) : -1;
}

static int Hook_sysctlbyname(const char* name, void* oldp, size_t* oldlenp, void* newp, size_t newlen) {
    if (name && (strstr(name, "debugger") || strstr(name, "security"))) {
        NSLog(@"[Hook] Blocked sysctlbyname: %s", name);
        return -1;
    }
    return o_sysctlbyname ? o_sysctlbyname(name, oldp, oldlenp, newp, newlen) : -1;
}

// ===== Screenshot Hooks =====
static void Hook_screenshot(id self, SEL _cmd) {
    NSLog(@"[Hook] Blocked screenshot");
}

static void Hook_screenshotOfView(id self, SEL _cmd, UIView* view) {
    NSLog(@"[Hook] Blocked screenshotOfView");
}

// ===== نظام التثبيت =====
struct HookEntry {
    const char* symbolName;
    void* hookFunction;
    void** originalPtr;
    bool installed;
};

static std::vector<HookEntry> hookEntries;

static void AddHook(const char* name, void* hook, void** original) {
    hookEntries.push_back({name, hook, original, false});
}

static void InitializeHooks() {
    // AnoSDK Hooks
    AddHook("AnoSDKInit", (void*)Hook_AnoSDKInit, (void**)&o_AnoSDKInit);
    AddHook("AnoSDKInitEx", (void*)Hook_AnoSDKInitEx, (void**)&o_AnoSDKInitEx);
    AddHook("AnoSDKIoctl", (void*)Hook_AnoSDKIoctl, (void**)&o_AnoSDKIoctl);
    AddHook("AnoSDKIoctlOld", (void*)Hook_AnoSDKIoctlOld, (void**)&o_AnoSDKIoctlOld);
    AddHook("AnoSDKGetReportData", (void*)Hook_AnoSDKGetReportData, (void**)&o_AnoSDKGetReportData);
    AddHook("AnoSDKGetReportData2", (void*)Hook_AnoSDKGetReportData2, (void**)&o_AnoSDKGetReportData2);
    AddHook("AnoSDKGetReportData3", (void*)Hook_AnoSDKGetReportData3, (void**)&o_AnoSDKGetReportData3);
    AddHook("AnoSDKGetReportData4", (void*)Hook_AnoSDKGetReportData4, (void**)&o_AnoSDKGetReportData4);
    AddHook("AnoSDKDelReportData", (void*)Hook_AnoSDKDelReportData, (void**)&o_AnoSDKDelReportData);
    AddHook("AnoSDKDelReportData3", (void*)Hook_AnoSDKDelReportData3, (void**)&o_AnoSDKDelReportData3);
    AddHook("AnoSDKDelReportData4", (void*)Hook_AnoSDKDelReportData4, (void**)&o_AnoSDKDelReportData4);
    AddHook("AnoSDKOnRecvData", (void*)Hook_AnoSDKOnRecvData, (void**)&o_AnoSDKOnRecvData);
    AddHook("AnoSDKOnRecvSignature", (void*)Hook_AnoSDKOnRecvSignature, (void**)&o_AnoSDKOnRecvSignature);
    AddHook("AnoSDKSetUserInfo", (void*)Hook_AnoSDKSetUserInfo, (void**)&o_AnoSDKSetUserInfo);
    AddHook("AnoSDKSetUserInfoWithLicense", (void*)Hook_AnoSDKSetUserInfoWithLicense, (void**)&o_AnoSDKSetUserInfoWithLicense);
    AddHook("AnoSDKRegistInfoListener", (void*)Hook_AnoSDKRegistInfoListener, (void**)&o_AnoSDKRegistInfoListener);
    
    // System Hooks
    AddHook("sysctl", (void*)Hook_sysctl, (void**)&o_sysctl);
    AddHook("sysctlbyname", (void*)Hook_sysctlbyname, (void**)&o_sysctlbyname);
}

static void InstallAllHooks() {
    int successCount = 0;
    int failCount = 0;
    
    for (auto& entry : hookEntries) {
        void* symbol = dlsym(RTLD_DEFAULT, entry.symbolName);
        if (symbol && symbol != entry.hookFunction) {
            if (InstallInlineHook(symbol, entry.hookFunction, entry.originalPtr)) {
                entry.installed = true;
                successCount++;
                NSLog(@"[Hook] ✓ %s hooked at %p", entry.symbolName, symbol);
            } else {
                failCount++;
                NSLog(@"[Hook] ✗ Failed to hook %s", entry.symbolName);
            }
        } else {
            NSLog(@"[Hook] - %s not found", entry.symbolName);
        }
    }
    
    NSLog(@"[Hook] Success: %d, Failed: %d", successCount, failCount);
}

static void InstallScreenshotHooks() {
    Class uiScreenClass = objc_getClass("UIScreen");
    if (uiScreenClass) {
        Method m = class_getInstanceMethod(uiScreenClass, @selector(screenshot));
        if (m) {
            method_setImplementation(m, (IMP)Hook_screenshot);
            NSLog(@"[Hook] ✓ UIScreen screenshot");
        }
    }
    
    Class uiViewClass = objc_getClass("UIView");
    if (uiViewClass) {
        Method m = class_getInstanceMethod(uiViewClass, @selector(screenshotOfView:));
        if (m) {
            method_setImplementation(m, (IMP)Hook_screenshotOfView);
            NSLog(@"[Hook] ✓ UIView screenshotOfView");
        }
    }
}

// ===== Constructor =====
__attribute__((constructor))
static void Initialize() {
    @autoreleasepool {
        NSLog(@"==================================");
        NSLog(@"[Hook] Starting Installation...");
        NSLog(@"==================================");
        
        InitializeHooks();
        InstallAllHooks();
        InstallScreenshotHooks();
        
        NSLog(@"==================================");
        NSLog(@"[Hook] Installation Complete!");
        NSLog(@"==================================");
    }
}
