//
//  DeltaForceLocator.m
//  doro工具箱
//
//  容器发现策略（按优先级）：
//   1) LaunchServices 数据库：wq_load_display_names() + wq_ls_container_paths(nil)
//      —— WQFiles 官方用来列出所有 app 数据容器的路径，最可靠。
//   2) 直接枚举 /private/var/mobile/Containers/Data/Application 父目录
//      —— worse_query 会按需 grant 父目录，作为数据库不可读时的兜底。
//  命中判定：<容器>/Documents/DeltaForce/Saved 是目录。
//  wq_stat 在被沙盒拒绝时会自动 wq_grant 父目录后重试，所以这里无需手动 grant。
//  复杂度：O(n)，n = 枚举到的容器数。
//

#import "DeltaForceLocator.h"
#import "WQAccess.h"
#import "WQLaunchServices.h"
#import <UIKit/UIDevice.h>
#import <errno.h>
#import <sys/stat.h>

static NSString * const kRelativeSaved = @"Documents/DeltaForce/Saved";
static NSString * const kAppDataRoot   = @"/private/var/mobile/Containers/Data/Application";
// 用户确认的目标容器完整路径（Data/Application 中间没有空格）；先试它，命中即用
static NSString * const kPinnedRoot    = @"/private/var/mobile/Containers/Data/Application/ED9354EB-FB6C-4CA3A2E6-B0509CFA08FE/Documents/DeltaForce/Saved";

@implementation DeltaForceLocator

+ (nullable NSString *)findSavedRoot:(NSString * _Nullable * _Nullable)errorText {
    NSMutableArray<NSString *> *notes = [NSMutableArray array];

    // 0) 环境自检：worse_query 依赖 App Group entitlement，签名后丢失会全线失败
    NSString *grp = wq_app_group();
    [notes addObject:[NSString stringWithFormat:@"iOS %@，AppGroup=%@",
                      UIDevice.currentDevice.systemVersion, grp ?: @"缺失"]];
    NSString *pinnedParent = kPinnedRoot.stringByDeletingLastPathComponent;
    BOOL granted = wq_grant(pinnedParent);
    int grantErr = errno;
    [notes addObject:granted
        ? @"确认路径授权成功"
        : [NSString stringWithFormat:@"确认路径授权失败 errno=%d", grantErr]];

    // 优先用确认过的完整路径；wq_stat 被拒时会自动 grant 后重试
    struct stat pinned;
    if (wq_stat(kPinnedRoot, &pinned) == 0 && S_ISDIR(pinned.st_mode)) {
        [notes addObject:[NSString stringWithFormat:@"命中确认路径 %@", kPinnedRoot.lastPathComponent]];
        return kPinnedRoot;
    }

    // 1) LaunchServices 数据库。发现数据库可能较慢，调用方已在后台队列。
    wq_load_display_names();
    NSArray<NSString *> *containers = wq_ls_container_paths(nil);
    [notes addObject:containers.count
        ? [NSString stringWithFormat:@"LaunchServices 列出 %lu 个容器", (unsigned long)containers.count]
        : @"LaunchServices 未返回容器（数据库不可读）"];

    NSString *found = [self scanContainers:containers notes:notes];
    if (found) return found;

    // 2) 兜底：直接列 App Data 父目录，worse_query 按需申请 token。
    NSString *listErr = nil;
    NSArray<NSString *> *children = wq_list(kAppDataRoot, &listErr);
    if (children.count) {
        [notes addObject:[NSString stringWithFormat:@"直接枚举 App Data 得到 %lu 项", (unsigned long)children.count]];
        NSMutableArray<NSString *> *full = [NSMutableArray arrayWithCapacity:children.count];
        for (NSString *name in children) {
            if (![name isKindOfClass:NSString.class] || name.length == 0) continue;
            [full addObject:[kAppDataRoot stringByAppendingPathComponent:name]];
        }
        found = [self scanContainers:full notes:notes];
        if (found) return found;
    } else {
        [notes addObject:[NSString stringWithFormat:@"直接枚举 App Data 失败：%@", listErr ?: @"未知"]];
    }

    if (errorText) {
        *errorText = [NSString stringWithFormat:@"%@；未找到 Documents/DeltaForce/Saved",
                      [notes componentsJoinedByString:@"；"]];
    }
    return nil;
}

// 逐个容器检查 <容器>/Documents/DeltaForce/Saved 是否为目录。
+ (nullable NSString *)scanContainers:(NSArray<NSString *> *)containers
                                notes:(NSMutableArray<NSString *> *)notes {
    struct stat st;
    NSUInteger checked = 0;
    for (NSString *c in containers) {
        if (![c isKindOfClass:NSString.class] || c.length == 0) continue;
        NSString *candidate = [c stringByAppendingPathComponent:kRelativeSaved];
        checked++;
        if (wq_stat(candidate, &st) == 0 && S_ISDIR(st.st_mode)) {
            NSString *bid = wq_bundle_id_for_container(c);
            NSString *label = bid ? wq_display_name(bid) : nil;
            [notes addObject:[NSString stringWithFormat:@"命中容器 %@（bundle=%@，名称=%@）",
                              c.lastPathComponent, bid ?: @"未知", label ?: @"未知"]];
            return candidate;
        }
    }
    if (checked) {
        [notes addObject:[NSString stringWithFormat:@"检查了 %lu 个容器均未命中", (unsigned long)checked]];
    }
    return nil;
}

@end
