//
//  DoroSBAppExit.m
//  SpringBoard 侧退出 App：
//  1) 私有 API LSApplicationWorkspace -terminateApplication:forReason: 优雅退出；
//  2) 兜底：按 bundleID 找ExecutableName，sysctl 遍历进程 kill(SIGTERM)。
//  仅退出工具箱自身，不动目标游戏。
//

#import "DoroSBAppExit.h"
#import <UIKit/UIKit.h>
#import <sys/sysctl.h>
#import <signal.h>
#import <string.h>

// SpringBoard 私有类/方法（运行时调用，编译期只做声明）
@interface LSApplicationWorkspace : NSObject
+ (instancetype)defaultWorkspace;
- (BOOL)terminateApplication:(NSString *)bundleID forReason:(long long)reason;
- (NSArray *)allApplications;
@end

@protocol DoroSBAppInfo <NSObject>
- (NSString *)bundleIdentifier;
- (NSString *)executableName;
@end

@implementation DoroSBAppExit

+ (void)terminateBundle:(NSString *)bundleID {
    if (!bundleID.length) return;
    LSApplicationWorkspace *ws = [NSClassFromString(@"LSApplicationWorkspace") defaultWorkspace];
    if (!ws) return;

    // 1) 优雅退出
    if ([ws respondsToSelector:@selector(terminateApplication:forReason:)]) {
        BOOL ok = [ws terminateApplication:bundleID forReason:0];
        NSLog(@"[DoroSB] terminate %@ via LSWorkspace = %d", bundleID, ok);
        if (ok) return;
    }

    // 2) 兜底 kill：从 workspace 拿可执行名，sysctl 扫进程匹配后发 SIGTERM
    NSString *exe = nil;
    for (id<DoroSBAppInfo> app in ([ws respondsToSelector:@selector(allApplications)] ? [ws allApplications] : @[])) {
        if ([[app bundleIdentifier] isEqualToString:bundleID]) { exe = [app executableName]; break; }
    }
    if (!exe.length) return;

    int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0};
    size_t size = 0;
    if (sysctl(mib, 4, NULL, &size, NULL, 0) != 0) return;
    struct kinfo_proc *procs = malloc(size);
    if (!procs) return;
    if (sysctl(mib, 4, procs, &size, NULL, 0) == 0) {
        int n = (int)(size / sizeof(struct kinfo_proc));
        for (int i = 0; i < n; i++) {
            const char *comm = procs[i].kp_proc.p_comm;
            if (comm && strcmp(comm, exe.UTF8String) == 0) {
                kill(procs[i].kp_proc.p_pid, SIGTERM);
                NSLog(@"[DoroSB] killed %@ pid=%d", exe, procs[i].kp_proc.p_pid);
            }
        }
    }
    free(procs);
}

@end
