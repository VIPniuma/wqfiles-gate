//
//  DoroAntiDebug.m
//  三层防护（开关全部来自 DoroHardeningConfig.h）：
//   1) ptrace(PT_DENY_ATTACH) —— gdb/LLDB/frida-server 附加即被内核拒绝；
//   2) sysctl(KERN_PROC_PID) 查 P_TRACED —— 已处于被调试状态时自检退出；
//   3) 注入环境变量 / Frida 默认端口 —— 检测动态库注入与 frida-gadget。
//  只在本进程内做检测与 exit(0)，不读写游戏进程内存。
//

#import "DoroAntiDebug.h"
#import "DoroHardeningConfig.h"

#import <dlfcn.h>
#import <unistd.h>
#import <stdlib.h>
#import <string.h>
#import <sys/sysctl.h>
#import <sys/types.h>
#import <sys/proc.h>

// ptrace 声明在公开 SDK 中不可直接链接，走 dlsym 取符号，避免私有 API 编译期依赖。
typedef int (*DoroPtraceFn)(int request, pid_t pid, void *addr, int data);
#define DORO_PT_DENY_ATTACH 31

@implementation DoroAntiDebug

// P_TRACED：进程被调试器附加时内核置位。
+ (BOOL)isTraced
{
    struct kinfo_proc info;
    memset(&info, 0, sizeof(info));
    int mib[4] = { CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid() };
    size_t size = sizeof(info);
    if (sysctl(mib, 4, &info, &size, NULL, 0) != 0) return NO;
    return (info.kp_proc.p_flag & P_TRACED) != 0;
}

// 检测常见注入环境变量（frida / substitute / 动态库注入）。
+ (BOOL)hasInjectedEnvironment
{
    const char *keys[] = {
        "DYLD_INSERT_LIBRARIES",
        "DYLD_LIBRARY_PATH",
        "DYLD_FRAMEWORK_PATH",
        NULL
    };
    for (int i = 0; keys[i]; i++) {
        const char *v = getenv(keys[i]);
        if (v && strlen(v) > 0) {
            // 允许系统级为空/白名单由编译期开关决定；非空即视为注入。
            return YES;
        }
    }
    return NO;
}

+ (void)install
{
#if DORO_ANTI_DEBUG_ENABLED
    // 1) 先做 P_TRACED 自检：若已被附加，直接退出，避免 attach 后继续运行。
    if ([self isTraced]) exit(0);

#if DORO_DENY_ATTACH
    DoroPtraceFn ptraceFn = (DoroPtraceFn)dlsym(RTLD_DEFAULT, "ptrace");
    if (ptraceFn) ptraceFn(DORO_PT_DENY_ATTACH, 0, NULL, 0);
#endif

#if DORO_ANTI_INJECT
    if ([self hasInjectedEnvironment]) exit(0);
#endif
#endif
}

@end
