//
//  DeltaForceLocator.m
//  复刻自黑猫工具箱 WQGameScanApps (Mach-O 0x10003ac78)
//
//  识别算法（纯特征，不写死 UUID / 不依赖 bundle id 可读）：
//   1) 收集所有数据容器（UUID 目录名）：
//      - wq_ls_container_paths（LaunchServices 数据库）
//      - wq_list(/private/var/mobile/Containers/Data/Application)
//      - wq_enumerate（fsgetpath 扫 inode，不受沙盒目录列表限制）
//   2) 逐个容器拼 Documents/DeltaForce，用 wq_stat 判目录；命中者即三角洲。
//      bundle id / metadata.plist 只作显示备注，不参与判定。
//   3) wq_grant 命中容器拿 token，返回容器根（token 精确覆盖该路径）。
//
//  所有访问都走 WQAccess（worse_query 沙箱逃逸：wq_grant 拿 token 后重试）。
//  复杂度：O(n)，n = 容器数。
//

#import "DeltaForceLocator.h"
#import "WQAccess.h"
#import "WQLaunchServices.h"
#import <UIKit/UIDevice.h>
#import <errno.h>
#import <sys/stat.h>

// 特征目录：DeltaForce（游戏必然创建）；Saved 交给写入模块新建
static NSString * const kFeatureRel  = @"Documents/DeltaForce";
static NSString * const kAppDataRoot = @"/private/var/mobile/Containers/Data/Application";

@implementation DeltaForceLocator

+ (nullable NSString *)findSavedRoot:(NSString * _Nullable * _Nullable)errorText {
    NSMutableArray<NSString *> *notes = [NSMutableArray array];
    NSString *grp = wq_app_group();
    [notes addObject:[NSString stringWithFormat:@"iOS %@ · AppGroup=%@",
                      UIDevice.currentDevice.systemVersion, grp ?: @"缺失（签名未带 App Group，逃沙箱必然失败）"]];

    wq_display_names_reset_miss();
    wq_load_display_names();

    // 1) 收集所有容器（去重）
    NSMutableArray<NSString *> *containers = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];

    NSArray *ls = wq_ls_container_paths(nil) ?: @[];
    [notes addObject:ls.count
        ? [NSString stringWithFormat:@"LaunchServices 列出 %lu 个容器", (unsigned long)ls.count]
        : @"LaunchServices 未返回容器"];
    [self addContainers:ls to:containers seen:seen];

    NSString *listErr = nil;
    NSArray *children = wq_list(kAppDataRoot, &listErr);
    if (children.count) {
        [notes addObject:[NSString stringWithFormat:@"wq_list 得到 %lu 项", (unsigned long)children.count]];
        NSMutableArray *full = [NSMutableArray arrayWithCapacity:children.count];
        for (NSString *name in children) {
            if ([name isKindOfClass:NSString.class] && name.length)
                [full addObject:[kAppDataRoot stringByAppendingPathComponent:name]];
        }
        [self addContainers:full to:containers seen:seen];
    } else {
        [notes addObject:[NSString stringWithFormat:@"wq_list 失败：%@", listErr ?: @"未知"]];
    }

    NSArray *enumerated = wq_enumerate(kAppDataRoot, 0, nil, nil) ?: @[];
    [notes addObject:enumerated.count
        ? [NSString stringWithFormat:@"wq_enumerate 得到 %lu 项", (unsigned long)enumerated.count]
        : @"wq_enumerate 无结果"];
    [self addContainers:enumerated to:containers seen:seen];

    [notes addObject:[NSString stringWithFormat:@"共 %lu 个唯一容器待检查", (unsigned long)containers.count]];

    // 2) 逐个检查特征目录 Documents/DeltaForce；谁有谁就是三角洲
    struct stat st;
    NSUInteger checked = 0;
    for (NSString *c in containers) {
        if (![c isKindOfClass:NSString.class] || c.length == 0) continue;
        NSString *feature = [c stringByAppendingPathComponent:kFeatureRel];
        checked++;
        if (wq_stat(feature, &st) == 0 && S_ISDIR(st.st_mode)) {
            NSString *bid = [self labelForContainer:c];
            wq_grant(c);   // 拿容器 token，返回容器根（token 精确覆盖）
            [notes addObject:[NSString stringWithFormat:@"命中容器 %@（bundle=%@，特征=%@）",
                              c.lastPathComponent, bid ?: @"未知", kFeatureRel]];
            if (errorText) *errorText = [notes componentsJoinedByString:@"；"];
            return c;
        }
    }

    if (errorText) {
        *errorText = [NSString stringWithFormat:@"%@；检查 %lu 个容器均无特征目录 %@",
                      [notes componentsJoinedByString:@"；"], (unsigned long)checked, kFeatureRel];
    }
    return nil;
}

// 容器去重加入
+ (void)addContainers:(NSArray<NSString *> *)items to:(NSMutableArray<NSString *> *)out seen:(NSMutableSet<NSString *> *)seen {
    for (NSString *c in items) {
        if (![c isKindOfClass:NSString.class] || c.length == 0) continue;
        NSString *key = c.stringByStandardizingPath;
        if ([seen containsObject:key]) continue;
        [seen addObject:key];
        [out addObject:c];
    }
}

// 容器 label 双通道（仅显示用）：xattr / metadata.plist 优先，回退 LaunchServices
+ (nullable NSString *)labelForContainer:(NSString *)container {
    NSString *bid = wq_container_label(container);
    if (!bid.length) bid = wq_bundle_id_for_container(container);
    return bid;
}

@end
