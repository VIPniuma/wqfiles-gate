//
//  DeltaForceLocator.m
//  复刻自黑猫工具箱 WQGameScanApps (Mach-O 0x10003ac78)
//
//  识别算法（不写死 UUID，UUID 是枚举出来的容器目录名）：
//   1) 已知完整路径优先（对应黑猫"手动填写容器 UUID / 完整路径"）。
//   2) wq_display_names_reset_miss + wq_load_display_names + wq_ls_container_paths
//      列出所有 app 数据容器；逐个拼 Documents/DeltaForce/Saved 用 wq_stat 验证
//      特征目录；同时 wq_bundle_id_for_container / wq_display_name 记录名称。
//   3) wq_enumerate 扫描 App Data 父目录，作为 LaunchServices 库不可读时的兜底。
//  命中后对每个候选容器 wq_grant，保证后续写入能拿到 sandbox extension token。
//  复杂度：O(n)，n = 容器数。
//

#import "DeltaForceLocator.h"
#import "WQAccess.h"
#import "WQLaunchServices.h"
#import <UIKit/UIDevice.h>
#import <errno.h>
#import <sys/stat.h>

static NSString * const kFeatureRel   = @"Documents/DeltaForce/Saved";
static NSString * const kAppDataRoot  = @"/private/var/mobile/Containers/Data/Application";
// 用户提供的已知完整路径（聊天里 Data/ Application 的空格是换行，真实路径无空格）
static NSString * const kKnownRoot    = @"/private/var/mobile/Containers/Data/Application/ED9354EB-FB6C-4CA3A2E6-B0509CFA08FE/Documents/DeltaForce/Saved";

@implementation DeltaForceLocator

+ (nullable NSString *)findSavedRoot:(NSString * _Nullable * _Nullable)errorText {
    NSMutableArray<NSString *> *notes = [NSMutableArray array];
    NSString *grp = wq_app_group();
    [notes addObject:[NSString stringWithFormat:@"iOS %@ · AppGroup=%@",
                      UIDevice.currentDevice.systemVersion, grp ?: @"缺失"]];

    // 1) 已知路径优先：wq_stat 被拒时内部自动 wq_grant 后重试
    [self grantParentOfPath:kKnownRoot notes:notes];
    struct stat st;
    if (wq_stat(kKnownRoot, &st) == 0 && S_ISDIR(st.st_mode)) {
        [notes addObject:[NSString stringWithFormat:@"命中已知容器 %@", [kKnownRoot pathComponents][4]]];
        return kKnownRoot;
    }

    // 2) LaunchServices 数据库（黑猫 WQGameScanApps 主路径）
    wq_display_names_reset_miss();
    wq_load_display_names();
    NSArray<NSString *> *containers = wq_ls_container_paths(nil);
    [notes addObject:containers.count
        ? [NSString stringWithFormat:@"LaunchServices 列出 %lu 个容器", (unsigned long)containers.count]
        : @"LaunchServices 未返回容器"];
    NSString *found = [self scanContainers:containers notes:notes];
    if (found) return found;

    // 3) wq_list 父目录
    NSString *listErr = nil;
    NSArray<NSString *> *children = wq_list(kAppDataRoot, &listErr);
    if (children.count) {
        [notes addObject:[NSString stringWithFormat:@"wq_list 得到 %lu 项", (unsigned long)children.count]];
        NSMutableArray *full = [NSMutableArray arrayWithCapacity:children.count];
        for (NSString *name in children) {
            if ([name isKindOfClass:NSString.class] && name.length)
                [full addObject:[kAppDataRoot stringByAppendingPathComponent:name]];
        }
        found = [self scanContainers:full notes:notes];
        if (found) return found;
    } else {
        [notes addObject:[NSString stringWithFormat:@"wq_list 失败：%@", listErr ?: @"未知"]];
    }

    // 4) wq_enumerate inode 扫描（黑猫兜底）
    NSArray<NSString *> *enumerated = wq_enumerate(kAppDataRoot, 0, nil, nil);
    if (enumerated.count) {
        [notes addObject:[NSString stringWithFormat:@"wq_enumerate 得到 %lu 项", (unsigned long)enumerated.count]];
        found = [self scanContainers:enumerated notes:notes];
        if (found) return found;
    } else {
        [notes addObject:@"wq_enumerate 无结果"];
    }

    if (errorText) {
        *errorText = [NSString stringWithFormat:@"%@；未找到特征目录 %@",
                      [notes componentsJoinedByString:@"；"], kFeatureRel];
    }
    return nil;
}

// 对候选容器逐个验证特征目录；命中时记录 bundle/名称并 grant 整个容器。
+ (nullable NSString *)scanContainers:(NSArray<NSString *> *)containers
                                notes:(NSMutableArray<NSString *> *)notes {
    struct stat st;
    NSUInteger checked = 0;
    for (NSString *c in containers) {
        if (![c isKindOfClass:NSString.class] || c.length == 0) continue;
        NSString *candidate = [c stringByAppendingPathComponent:kFeatureRel];
        checked++;
        if (wq_stat(candidate, &st) == 0 && S_ISDIR(st.st_mode)) {
            wq_grant(c);
            NSString *bid = wq_bundle_id_for_container(c);
            NSString *label = bid.length ? wq_display_name(bid) : nil;
            [notes addObject:[NSString stringWithFormat:@"命中容器 %@（bundle=%@，名称=%@）",
                              c.lastPathComponent, bid ?: @"未知", label ?: @"未知"]];
            return candidate;
        }
    }
    if (checked) [notes addObject:[NSString stringWithFormat:@"检查 %lu 个容器均未命中", (unsigned long)checked]];
    return nil;
}

+ (void)grantParentOfPath:(NSString *)path notes:(NSMutableArray<NSString *> *)notes {
    NSString *parent = path.stringByDeletingLastPathComponent;
    BOOL ok = wq_grant(parent);
    [notes addObject:ok ? @"已知容器授权成功"
                        : [NSString stringWithFormat:@"已知容器授权失败 errno=%d", errno]];
}

@end
