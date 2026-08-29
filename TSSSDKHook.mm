// ===== TSSSDK Hook - بنفس طريقة HiggsBoson VTable Hooking =====
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>
#import <mach/mach.h>
#import <mach-o/dyld.h>
#import <sys/sysctl.h>
#import <sys/types.h>

#include <string>
#include <vector>
#include <map>
#include <algorithm>

// ===== المؤشرات الأصلية لجميع الدوال =====

// AnoSDK Functions
static void* (*oOrig_AnoSDKInit)(void*) = nullptr;
static void* (*oOrig_AnoSDKInitEx)(void*, void*) = nullptr;
static void* (*oOrig_AnoSDKIoctl)(void*, int, void*, int) = nullptr;
static void* (*oOrig_AnoSDKIoctlOld)(void*, int, void*, int) = nullptr;
static void* (*oOrig_AnoSDKGetReportData)(void*) = nullptr;
static void* (*oOrig_AnoSDKGetReportData2)(void*) = nullptr;
static void* (*oOrig_AnoSDKGetReportData3)(void*) = nullptr;
static void* (*oOrig_AnoSDKGetReportData4)(void*) = nullptr;
static void* (*oOrig_AnoSDKDelReportData)(void*) = nullptr;
static void* (*oOrig_AnoSDKDelReportData3)(void*) = nullptr;
static void* (*oOrig_AnoSDKDelReportData4)(void*) = nullptr;
static void* (*oOrig_AnoSDKOnRecvData)(void*, int) = nullptr;
static void* (*oOrig_AnoSDKOnRecvSignature)(void*, void*) = nullptr;
static void* (*oOrig_AnoSDKSetUserInfo)(void*, void*) = nullptr;
static void* (*oOrig_AnoSDKSetUserInfoWithLicense)(void*, void*, void*) = nullptr;
static void* (*oOrig_AnoSDKRegistInfoListener)(void*, void*) = nullptr;

// System Functions
static int (*oOrig_sysctl)(int*, u_int, void*, size_t*, void*, size_t) = nullptr;
static int (*oOrig_sysctlbyname)(const char*, void*, size_t*, void*, size_t) = nullptr;
static void* (*oOrig_dlopen)(const char*, int) = nullptr;
static void* (*oOrig_dlsym)(void*, const char*) = nullptr;
static int (*oOrig_dladdr)(void*, Dl_info*) = nullptr;
static kern_return_t (*oOrig_task_get_special_port)(task_t, int, mach_port_t*) = nullptr;
static int (*oOrig_pid_for_task)(task_t, pid_t*) = nullptr;
static kern_return_t (*oOrig_mach_vm_region_recurse)(vm_map_t, mach_vm_address_t*, mach_vm_size_t*, uint32_t*, vm_region_recurse_info_t, mach_msg_type_number_t*) = nullptr;
static kern_return_t (*oOrig_mach_vm_remap)(vm_map_t, mach_vm_address_t*, mach_vm_size_t, mach_vm_offset_t, int, vm_map_t, mach_vm_address_t, boolean_t, vm_prot_t*, vm_prot_t*, vm_inherit_t) = nullptr;
static int (*oOrig_proc_regionfilename)(int, uint64_t, void*, uint32_t) = nullptr;

// Other Functions
static void* (*oOrig_hash)(void*) = nullptr;
static void* (*oOrig_hash2)(void*) = nullptr;
static void* (*oOrig_tcj_encrypt)(void*, void*) = nullptr;
static void* (*oOrig_shell_report)(void*, void*) = nullptr;
static void* (*oOrig_tdm_report)(void*, void*) = nullptr;

// ===== دوال الاعتراض =====

// === AnoSDK Hooks ===
static void* Hook_AnoSDKInit(void* param1) {
    if (!param1) return oOrig_AnoSDKInit ? oOrig_AnoSDKInit(param1) : nullptr;
    return nullptr;
}

static void* Hook_AnoSDKInitEx(void* param1, void* param2) {
    if (!param1 || !param2) return oOrig_AnoSDKInitEx ? oOrig_AnoSDKInitEx(param1, param2) : nullptr;
    return nullptr;
}

static void* Hook_AnoSDKIoctl(void* handle, int cmd, void* data, int len) {
    if (!handle) return oOrig_AnoSDKIoctl ? oOrig_AnoSDKIoctl(handle, cmd, data, len) : nullptr;
    return nullptr;
}

static void* Hook_AnoSDKIoctlOld(void* handle, int cmd, void* data, int len) {
    if (!handle) return oOrig_AnoSDKIoctlOld ? oOrig_AnoSDKIoctlOld(handle, cmd, data, len) : nullptr;
    return nullptr;
}

static void* Hook_AnoSDKGetReportData(void* param) {
    if (!param) return oOrig_AnoSDKGetReportData ? oOrig_AnoSDKGetReportData(param) : nullptr;
    return nullptr;
}

static void* Hook_AnoSDKGetReportData2(void* param) {
    if (!param) return oOrig_AnoSDKGetReportData2 ? oOrig_AnoSDKGetReportData2(param) : nullptr;
    return nullptr;
}

static void* Hook_AnoSDKGetReportData3(void* param) {
    if (!param) return oOrig_AnoSDKGetReportData3 ? oOrig_AnoSDKGetReportData3(param) : nullptr;
    return nullptr;
}

static void* Hook_AnoSDKGetReportData4(void* param) {
    if (!param) return oOrig_AnoSDKGetReportData4 ? oOrig_AnoSDKGetReportData4(param) : nullptr;
    return nullptr;
}

static void* Hook_AnoSDKDelReportData(void* param) {
    if (!param) return oOrig_AnoSDKDelReportData ? oOrig_AnoSDKDelReportData(param) : nullptr;
    return nullptr;
}

static void* Hook_AnoSDKDelReportData3(void* param) {
    if (!param) return oOrig_AnoSDKDelReportData3 ? oOrig_AnoSDKDelReportData3(param) : nullptr;
    return nullptr;
}

static void* Hook_AnoSDKDelReportData4(void* param) {
    if (!param) return oOrig_AnoSDKDelReportData4 ? oOrig_AnoSDKDelReportData4(param) : nullptr;
    return nullptr;
}

static void* Hook_AnoSDKOnRecvData(void* data, int len) {
    if (!data || len <= 0) return oOrig_AnoSDKOnRecvData ? oOrig_AnoSDKOnRecvData(data, len) : nullptr;
    return nullptr;
}

static void* Hook_AnoSDKOnRecvSignature(void* param1, void* param2) {
    if (!param1 || !param2) return oOrig_AnoSDKOnRecvSignature ? oOrig_AnoSDKOnRecvSignature(param1, param2) : nullptr;
    return nullptr;
}

static void* Hook_AnoSDKSetUserInfo(void* param1, void* param2) {
    if (!param1 || !param2) return oOrig_AnoSDKSetUserInfo ? oOrig_AnoSDKSetUserInfo(param1, param2) : nullptr;
    return nullptr;
}

static void* Hook_AnoSDKSetUserInfoWithLicense(void* param1, void* param2, void* param3) {
    if (!param1 || !param2 || !param3) return oOrig_AnoSDKSetUserInfoWithLicense ? oOrig_AnoSDKSetUserInfoWithLicense(param1, param2, param3) : nullptr;
    return nullptr;
}

static void* Hook_AnoSDKRegistInfoListener(void* param1, void* param2) {
    if (!param1 || !param2) return oOrig_AnoSDKRegistInfoListener ? oOrig_AnoSDKRegistInfoListener(param1, param2) : nullptr;
    return nullptr;
}

// === System Hooks ===
static int Hook_sysctl(int* name, u_int namelen, void* oldp, size_t* oldlenp, void* newp, size_t newlen) {
    if (name && namelen >= 2 && name[0] == CTL_KERN && name[1] == KERN_PROC) {
        return -1;
    }
    return oOrig_sysctl ? oOrig_sysctl(name, namelen, oldp, oldlenp, newp, newlen) : -1;
}

static int Hook_sysctlbyname(const char* name, void* oldp, size_t* oldlenp, void* newp, size_t newlen) {
    if (name && (strstr(name, "debugger") || strstr(name, "security"))) {
        return -1;
    }
    return oOrig_sysctlbyname ? oOrig_sysctlbyname(name, oldp, oldlenp, newp, newlen) : -1;
}

static void* Hook_dlopen(const char* path, int mode) {
    if (path && (strstr(path, "TSSSDK") || strstr(path, "AnoSDK"))) {
        return nullptr;
    }
    return oOrig_dlopen ? oOrig_dlopen(path, mode) : nullptr;
}

static void* Hook_dlsym(void* handle, const char* symbol) {
    if (symbol && (strstr(symbol, "AnoSDK") || strstr(symbol, "TSSSDK"))) {
        return nullptr;
    }
    return oOrig_dlsym ? oOrig_dlsym(handle, symbol) : nullptr;
}

static kern_return_t Hook_task_get_special_port(task_t task, int which_port, mach_port_t* special_port) {
    return KERN_FAILURE;
}

static int Hook_pid_for_task(task_t task, pid_t* pid) {
    return -1;
}

static kern_return_t Hook_mach_vm_region_recurse(vm_map_t map, mach_vm_address_t* address, mach_vm_size_t* size, uint32_t* depth, vm_region_recurse_info_t info, mach_msg_type_number_t* infoCnt) {
    return KERN_FAILURE;
}

static kern_return_t Hook_mach_vm_remap(vm_map_t target, mach_vm_address_t* address, mach_vm_size_t size, mach_vm_offset_t mask, int flags, vm_map_t src, mach_vm_address_t src_address, boolean_t copy, vm_prot_t* cur_prot, vm_prot_t* max_prot, vm_inherit_t inherit) {
    return KERN_FAILURE;
}

static int Hook_proc_regionfilename(int pid, uint64_t address, void* buffer, uint32_t buffersize) {
    return -1;
}

// === Other Hooks ===
static void* Hook_hash(void* param) {
    if (!param) return oOrig_hash ? oOrig_hash(param) : nullptr;
    return nullptr;
}

static void* Hook_hash2(void* param) {
    if (!param) return oOrig_hash2 ? oOrig_hash2(param) : nullptr;
    return nullptr;
}

static void* Hook_tcj_encrypt(void* param1, void* param2) {
    if (!param1 || !param2) return oOrig_tcj_encrypt ? oOrig_tcj_encrypt(param1, param2) : nullptr;
    return nullptr;
}

static void* Hook_shell_report(void* param1, void* param2) {
    if (!param1 || !param2) return oOrig_shell_report ? oOrig_shell_report(param1, param2) : nullptr;
    return nullptr;
}

static void* Hook_tdm_report(void* param1, void* param2) {
    if (!param1 || !param2) return oOrig_tdm_report ? oOrig_tdm_report(param1, param2) : nullptr;
    return nullptr;
}

// ===== نظام البحث والتثبيت بنفس طريقة RTL_language =====

struct HookTarget {
    const char* symbolName;
    void* hookFunction;
    void** originalPtr;
    bool found;
};

static std::vector<HookTarget> hookTargets;

static void InitializeHookTargets() {
    // AnoSDK
    hookTargets.push_back({"AnoSDKInit", (void*)Hook_AnoSDKInit, (void**)&oOrig_AnoSDKInit, false});
    hookTargets.push_back({"AnoSDKInitEx", (void*)Hook_AnoSDKInitEx, (void**)&oOrig_AnoSDKInitEx, false});
    hookTargets.push_back({"AnoSDKIoctl", (void*)Hook_AnoSDKIoctl, (void**)&oOrig_AnoSDKIoctl, false});
    hookTargets.push_back({"AnoSDKIoctlOld", (void*)Hook_AnoSDKIoctlOld, (void**)&oOrig_AnoSDKIoctlOld, false});
    hookTargets.push_back({"AnoSDKGetReportData", (void*)Hook_AnoSDKGetReportData, (void**)&oOrig_AnoSDKGetReportData, false});
    hookTargets.push_back({"AnoSDKGetReportData2", (void*)Hook_AnoSDKGetReportData2, (void**)&oOrig_AnoSDKGetReportData2, false});
    hookTargets.push_back({"AnoSDKGetReportData3", (void*)Hook_AnoSDKGetReportData3, (void**)&oOrig_AnoSDKGetReportData3, false});
    hookTargets.push_back({"AnoSDKGetReportData4", (void*)Hook_AnoSDKGetReportData4, (void**)&oOrig_AnoSDKGetReportData4, false});
    hookTargets.push_back({"AnoSDKDelReportData", (void*)Hook_AnoSDKDelReportData, (void**)&oOrig_AnoSDKDelReportData, false});
    hookTargets.push_back({"AnoSDKDelReportData3", (void*)Hook_AnoSDKDelReportData3, (void**)&oOrig_AnoSDKDelReportData3, false});
    hookTargets.push_back({"AnoSDKDelReportData4", (void*)Hook_AnoSDKDelReportData4, (void**)&oOrig_AnoSDKDelReportData4, false});
    hookTargets.push_back({"AnoSDKOnRecvData", (void*)Hook_AnoSDKOnRecvData, (void**)&oOrig_AnoSDKOnRecvData, false});
    hookTargets.push_back({"AnoSDKOnRecvSignature", (void*)Hook_AnoSDKOnRecvSignature, (void**)&oOrig_AnoSDKOnRecvSignature, false});
    hookTargets.push_back({"AnoSDKSetUserInfo", (void*)Hook_AnoSDKSetUserInfo, (void**)&oOrig_AnoSDKSetUserInfo, false});
    hookTargets.push_back({"AnoSDKSetUserInfoWithLicense", (void*)Hook_AnoSDKSetUserInfoWithLicense, (void**)&oOrig_AnoSDKSetUserInfoWithLicense, false});
    hookTargets.push_back({"AnoSDKRegistInfoListener", (void*)Hook_AnoSDKRegistInfoListener, (void**)&oOrig_AnoSDKRegistInfoListener, false});
    
    // System
    hookTargets.push_back({"sysctl", (void*)Hook_sysctl, (void**)&oOrig_sysctl, false});
    hookTargets.push_back({"sysctlbyname", (void*)Hook_sysctlbyname, (void**)&oOrig_sysctlbyname, false});
    hookTargets.push_back({"dlopen", (void*)Hook_dlopen, (void**)&oOrig_dlopen, false});
    hookTargets.push_back({"dlsym", (void*)Hook_dlsym, (void**)&oOrig_dlsym, false});
    hookTargets.push_back({"task_get_special_port", (void*)Hook_task_get_special_port, (void**)&oOrig_task_get_special_port, false});
    hookTargets.push_back({"pid_for_task", (void*)Hook_pid_for_task, (void**)&oOrig_pid_for_task, false});
    hookTargets.push_back({"mach_vm_region_recurse", (void*)Hook_mach_vm_region_recurse, (void**)&oOrig_mach_vm_region_recurse, false});
    hookTargets.push_back({"mach_vm_remap", (void*)Hook_mach_vm_remap, (void**)&oOrig_mach_vm_remap, false});
    hookTargets.push_back({"proc_regionfilename", (void*)Hook_proc_regionfilename, (void**)&oOrig_proc_regionfilename, false});
    
    // Other
    hookTargets.push_back({"hash", (void*)Hook_hash, (void**)&oOrig_hash, false});
    hookTargets.push_back({"hash2", (void*)Hook_hash2, (void**)&oOrig_hash2, false});
    hookTargets.push_back({"tcj_encrypt", (void*)Hook_tcj_encrypt, (void**)&oOrig_tcj_encrypt, false});
    hookTargets.push_back({"shell_report", (void*)Hook_shell_report, (void**)&oOrig_shell_report, false});
    hookTargets.push_back({"tdm_report", (void*)Hook_tdm_report, (void**)&oOrig_tdm_report, false});
}

// ===== دالة التثبيت - بنفس طريقة RTL_language =====
static void* RTL_InstallTSSSDKHooks() {
    NSLog(@"[TSSSDK Hook] Searching for symbols...");
    
    int hookedCount = 0;
    
    for (auto& target : hookTargets) {
        if (target.found) continue;
        
        void* symbol = dlsym(RTLD_DEFAULT, target.symbolName);
        if (symbol) {
            target.found = true;
            *target.originalPtr = symbol;
            hookedCount++;
            NSLog(@"[TSSSDK Hook] ✓ Found %s at %p", target.symbolName, symbol);
        }
    }
    
    NSLog(@"[TSSSDK Hook] Found %d symbols", hookedCount);
    return nullptr;
}

// ===== البحث في VTable - بنفس طريقة الكود الأصلي =====
static void* SearchVTableForTSSSDK() {
    // البحث في جميع الصور المحملة
    uint32_t imageCount = _dyld_image_count();
    for (uint32_t i = 0; i < imageCount; i++) {
        const char* imageName = _dyld_get_image_name(i);
        if (!imageName) continue;
        
        if (strstr(imageName, "TSSSDK") || 
            strstr(imageName, "AnoSDK") ||
            strstr(imageName, "Security") ||
            strstr(imageName, "Protect") ||
            strstr(imageName, "AntiCheat")) {
            
            NSLog(@"[TSSSDK Hook] Found library: %s", imageName);
            
            // البحث عن VTable في المكتبة
            const struct mach_header* header = _dyld_get_image_header(i);
            intptr_t slide = _dyld_get_image_vmaddr_slide(i);
            
            // البحث عن الفئات المعروفة
            const char* classNames[] = {
                "PluginTssSDKLifecycle",
                "TssInfoReceiver",
                "CSdkEventListener",
                "ITssEventListener",
                "CMrpcs",
                "CMrpcsMgr",
                "CAntiDataProxy",
                nullptr
            };
            
            for (int j = 0; classNames[j] != nullptr; j++) {
                Class cls = objc_getClass(classNames[j]);
                if (cls) {
                    NSLog(@"[TSSSDK Hook] Found class: %s", classNames[j]);
                    
                    // البحث عن VTable في الفئة
                    // يمكن الوصول إلى VTable من خلال الكائنات
                }
            }
        }
    }
    
    return nullptr;
}

// ===== Constructor =====
__attribute__((constructor))
static void InitializeTSSSDKHook() {
    @autoreleasepool {
        NSLog(@"========================================");
        NSLog(@"[TSSSDK Hook] Starting...");
        NSLog(@"========================================");
        
        // تهيئة الأهداف
        InitializeHookTargets();
        
        // تثبيت Hooks
        RTL_InstallTSSSDKHooks();
        
        // البحث في VTable
        SearchVTableForTSSSDK();
        
        NSLog(@"========================================");
        NSLog(@"[TSSSDK Hook] Complete!");
        NSLog(@"========================================");
    }
}
