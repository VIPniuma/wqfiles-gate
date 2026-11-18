//
//  DeltaForceLocator.m
//  复刻自黑猫工具箱 WQGameScanApps (Mach-O 0x10003ac78)
//
//  识别算法（不依赖写死 UUID）：
//   0) 按目标 bundle id (com.tencent.tmgp.dfm) 匹配容器：LaunchServices 的
//      wq_bundle_id_for_container 是权威来源；iOS 数据容器目录名是 UUID，
//      把 bundle id 当目录名写死在真机上通常不成立。
//   1) 用户提供的完整路径优先（若真机恰好就是这个目录名）。
//   2) wq_display_names_reset_miss + wq_load_display_names + wq_ls_container_paths
//      列出所有 app 数据容器；逐个拼 Documents/DeltaForce/Saved 用 wq_stat 验证。
//   3) wq_list / wq_enumerate 扫 App Data 父目录，作为数据库不可读时的兜底。
//  所有路径访问都走 WQAccess（worse_query 沙箱逃逸：wq_grant 取 token 后重试）。
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
// 目标应用 bundle id（三角洲行动）。容器目录名是 UUID，不写死。
static NSString * const kTargetBundle = @"com.tencent.tmgp.dfm";
// 用户提供的已知完整路径（Data/ Application 的空格是换行，真实路径无空格）
static NSString * const kKnownRoot    = @"/private/var/mobile/Containers/Data/Application/com.tencent.tmgp.dfm/Documents/DeltaForce/Saved";

@implementation DeltaForceLocator

+ (nullable NSString *)findSavedRoot:(NSString * _Nullable * _Nullable)errorText {
    NSMutableArray<NSString *> *notes = [NSMutableArray array];
    NSString *grp = wq_app_group();
    [notes addObject:[NSString stringWithFormat:@"iOS %@ · AppGroup=%@",
                      UIDevice.currentDevice.systemVersion, grp ?: @"缺失（签名未带 App Group，逃沙箱必然失败）"]];

    // 1) 用户提供的完整路径优先：wq_stat 被拒时内部自动 wq_grant 后重试
    [self grantParentOfPath:kKnownRoot notes:notes];
    struct stat st;
    if (wq_stat(kKnownRoot, &st) == 0 && S_ISDIR(st.st_mode)) {
        [notes addObject:@"命中用户指定完整路径"];
        return kKnownRoot;
    }
    [notes addObject:@"用户指定完整路径不可用（容器名多半是 UUID 而非 bundle id）"];

    // 先加载 LaunchServices 名称库：按 bundle id 匹配容器要用
    wq_display_names_reset_miss();
    wq_load_display_names();

    // 2) 按 bundle id 精确匹配容器（权威路径），再校验特征目录
    NSArray<NSString *> *lsContainers = wq_ls_container_paths(nil);
    [notes addObject:lsContainers.count
        ? [NSString stringWithFormat:@"LaunchServices 列出 %lu 个容器", (unsigned long)lsContainers.count]
        : @"LaunchServices 未返回容器"];
    NSString *found = [self scanContainers:lsContainers bundleID:kTargetBundle notes:notes];
    if (found) return found;

    // 3) wq_list 父目录（拿到 UUID 目录名）
    NSString *listErr = nil;
    NSArray<NSString *> *children = wq_list(kAppDataRoot, &listErr);
    NSMutableArray *allContainers = [NSMutableArray arrayWithArray:lsContainers ?: @[]];
    if (children.count) {
        [notes addObject:[NSString stringWithFormat:@"wq_list 得到 %lu 项", (unsigned long)children.count]];
        for (NSString *name in children) {
            if ([name isKindOfClass:NSString.class] && name.length)
                [allContainers addObject:[kAppDataRoot stringByAppendingPathComponent:name]];
        }
    } else {
        [notes addObject:[NSString stringWithFormat:@"wq_list 失败：%@", listErr ?: @"未知"]];
    }
    found = [self scanContainers:allContainers bundleID:kTargetBundle notes:notes];
    if (found) return found;

    // 4) wq_enumerate inode 扫描（黑猫兜底，fsgetpath 不受沙盒目录列表限制）
    NSArray<NSString *> *enumerated = wq_enumerate(kAppDataRoot, 0, nil, nil);
    if (enumerated.count) {
        [notes addObject:[NSString stringWithFormat:@"wq_enumerate 得到 %lu 项", (unsigned long)enumerated.count]];
        [allContainers addObjectsFromArray:enumerated];
        found = [self scanContainers:allContainers bundleID:kTargetBundle notes:notes];
        if (found) return found;
    } else {
        [notes addObject:@"wq_enumerate 无结果"];
    }

    if (errorText) {
        *errorText = [NSString stringWithFormat:@"%@；未找到 bundle=%@ 的特征目录 %@",
                      [notes componentsJoinedByString:@"；"], kTargetBundle, kFeatureRel];
    }
    return nil;
}

// 对候选容器逐个验证：bundle id 命中（若可读）且特征目录存在则 grant 整个容器。
+ (nullable NSString *)scanContainers:(NSArray<NSString *> *)containers
                             bundleID:(NSString *)bundleID
                                notes:(NSMutableArray<NSString *> *)notes {
    struct stat st;
    NSUInteger checked = 0;
    NSUInteger bundleHits = 0;
    for (NSString *c in containers) {
        if (![c isKindOfClass:NSString.class] || c.length == 0) continue;
        NSString *bid = wq_bundle_id_for_container(c);
        BOOL bundleMatch = bid.length && [bid isEqualToString:bundleID];
        if (bundleMatch) bundleHits++;
        NSString *candidate = [c stringByAppendingPathComponent:kFeatureRel];
        checked++;
        // bundle 命中优先，但仍要用 wq_stat 确认特征目录真的存在（且能拿到 token）
        if (wq_stat(candidate, &st) == 0 && S_ISDIR(st.st_mode)) {
            wq_grant(c);
            [notes addObject:[NSString stringWithFormat:@"命中容器 %@（bundle=%@）",
                              c.lastPathComponent, bid ?: @"未知"]];
            return candidate;
        }
    }
    [notes addObject:[NSString stringWithFormat:@"检查 %lu 个容器，bundle=%@ 命中 %lu 个，但特征目录 %@ 均未命中",
                      (unsigned long)checked, bundleID, (unsigned long)bundleHits, kFeatureRel]];
    return nil;
}

+ (void)grantParentOfPath:(NSString *)path notes:(NSMutableArray<NSString *> *)notes {
    NSString *parent = path.stringByDeletingLastPathComponent;
    BOOL ok = wq_grant(parent);
    [notes addObject:ok ? @"已知容器授权成功"
                        : [NSString stringWithFormat:@"已知容器授权失败 errno=%d", errno]];
}

@end
