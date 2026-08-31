#ifndef TSSSDK_HOOK_H
#define TSSSDK_HOOK_H

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

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

bool InitializeHookSystem(void);
bool EnableHookSystem(void);
bool DisableHookSystem(void);
bool RestoreHookSystem(void);
HookStatistics GetHookStatistics(void);

#ifdef __cplusplus
}
#endif

#endif
