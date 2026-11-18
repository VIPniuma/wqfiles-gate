//
//  DeltaForceLocator.m
//  复刻自黑猫工具箱 WQGameScanApps (Mach-O 0x10003ac78)
//
//  识别算法（纯特征，不写死 UUID / 不依赖 bundle id 可读）：
//   1) 收集所有数据容器（UUID 目录名）：
//      - wq_ls_container_paths（LaunchServices 数据库）
//      - wq_list(/private/var/mobile/Containers/Data/Application)
//      - wq_enumerate（fsgetpath 扫 inode，不受沙盒目录列表限制）
//   2) 逐个容器：wq_list 列出 Documents 下真实条目名，字母逐字比对
//      DeltaForce / Delta-Force 两个特征名（大小写不敏感、字母一个都不能差），再 wq_stat 确认是目录。
//      wq_list 被沙盒挡住时：先 wq_stat 直接探测两个候选名，仍失败才 wq_enumerate(inode) 兜底。
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

// 严格特征目录名（两个都认）：字母逐字匹配，大小写不敏感（iOS 目录大小写不敏感），
// 但字母本身一个都不能差。DeltaXForce / Delta force / DeltForce 一律不算。
static NSString * const kFeatureNames[] = { @"DeltaForce", @"Delta-Force" };
static NSString * const kFeatureKey  = @"deltaforce";   // 归一化后的目标（只留 a-z）
static NSString * const kDocsRel      = @"Documents";
static NSString * const kFeatureRel   = @"Documents/DeltaForce 或 Documents/Delta-Force";  // 仅显示用
static NSString * const kAppDataRoot = @"/private/var/mobile/Containers/Data/Application";

// 归一化特征名：只保留 a-z 字母，忽略大小写与 -/_/空格/零宽/全角连接符等一切非字母。
// 目标 key = "deltaforce"：DeltaForce / Delta-Force / Delta Force / DELTA_FORCE 都命中；
// DeltaXForce / DeltForce / DeltaForce2 不命中（字母一个都不能错）。
static NSString *wq_feature_key(NSString *s) {
    if (![s isKindOfClass:NSString.class]) return @"";
    NSMutableString *out = [NSMutableString stringWithCapacity:s.length];
    for (NSUInteger i = 0; i < s.length; i++) {
        unichar ch = [s characterAtIndex:i];
        if (ch >= 'A' && ch <= 'Z') ch = (unichar)(ch + ('a' - 'A'));
        if (ch >= 'a' && ch <= 'z') [out appendFormat:@"%c", (char)ch];
    }
    return out;
}

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

    // 2) 严格检查：对每个容器用两个精确候选名判定（大小写不敏感、字母逐字一致）
    struct stat st;
    NSUInteger checked = 0, listFailed = 0, statFallback = 0;
    NSMutableArray<NSString *> *nearHits = [NSMutableArray array];  // 近似样本，仅诊断
    NSUInteger featureCount = sizeof(kFeatureNames) / sizeof(kFeatureNames[0]);
    for (NSString *c in containers) {
        if (![c isKindOfClass:NSString.class] || c.length == 0) continue;
        checked++;
        NSString *docs = [c stringByAppendingPathComponent:kDocsRel];
        // 先拿容器 token 再列：wq_list 内部只 grant(docs)，容器根未授权时仍会失败
        wq_grant(c);
        wq_grant(docs);
        NSString *listErr = nil;
        NSArray *entries = wq_list(docs, &listErr);   // 只用于取真实拼写；失败不再直接判死
        if (!entries) listFailed++;

        NSString *matchedName = nil;
        BOOL matchedFromList = NO;
        for (NSUInteger fi = 0; fi < featureCount; fi++) {
            NSString *candidate = kFeatureNames[fi];
            NSString *probe = nil;
            if (entries) {
                // 列目录成功：对每个真实条目名做归一化比对（只比 a-z 字母），保留真实拼写。
                // 这一层不依赖 candidate 的拼写，DeltaForce / Delta-Force / 带零宽字符都命中。
                for (NSString *name in entries) {
                    if (![name isKindOfClass:NSString.class]) continue;
                    if ([wq_feature_key(name) isEqualToString:kFeatureKey]) {
                        probe = [docs stringByAppendingPathComponent:name];
                        matchedName = name;
                        matchedFromList = YES;   // wq_list 已证明它存在于 Documents 下，采信
                        break;
                    }
                }
            } else {
                // wq_list 被沙盒挡住：不依赖列目录，直接对精确候选名 wq_stat 探测。
                // wq_stat 内部会 grant(docs) 重试，比列目录更强；且只探两个固定名字，
                // 不会像 wq_enumerate(docs) 那样触发全卷 inode 扫描（iOS 26 可达 40 分钟）。
                probe = [docs stringByAppendingPathComponent:candidate];
            }
            if (!probe) continue;
            if (matchedFromList) break;   // 列目录命中即为目录条目，无需再 stat（沙盒下 stat 会假失败）

            struct stat probeSt = {0};
            if (wq_stat(probe, &probeSt) == 0 && S_ISDIR(probeSt.st_mode)) {
                matchedName = candidate;
                statFallback++;
                break;
            }
        }
        if (!matchedName) {
            // 诊断：列出任何与候选名"字母近似但不完全相等"的条目，一次定位隐藏字符/变体
            for (NSString *name in entries ?: @[]) {
                if (![name isKindOfClass:NSString.class]) continue;
                NSString *a = [name lowercaseString];
                if (a.length < 4) continue;
                BOOL similar = ([a containsString:@"delta"] || [a containsString:@"force"]);
                for (NSUInteger fi2 = 0; fi2 < featureCount && !similar; fi2++) {
                    NSString *b = [kFeatureNames[fi2] lowercaseString];
                    NSString *prefix = [a substringToIndex:MIN(4, a.length)];
                    if ([b hasPrefix:prefix]) similar = YES;
                }
                if (similar) {
                    [nearHits addObject:[NSString stringWithFormat:@"%@:Documents/%@(len%lu)",
                                         c.lastPathComponent, name, (unsigned long)name.length]];
                }
            }
            continue;
        }

        // 把命中名的 Unicode 码点打出来，若有隐藏字符一眼可见
        NSMutableArray *codes = [NSMutableArray array];
        for (NSUInteger i = 0; i < matchedName.length; i++) {
            [codes addObject:[NSString stringWithFormat:@"%04X", [matchedName characterAtIndex:i]]];
        }
        NSString *bid = [self labelForContainer:c];
        wq_grant(c);   // 拿容器 token，返回容器根（token 精确覆盖）
        BOOL isDir = (wq_stat([[docs stringByAppendingPathComponent:matchedName] stringByResolvingSymlinksInPath], &st) == 0 && S_ISDIR(st.st_mode));
        [notes addObject:[NSString stringWithFormat:@"严格命中容器 %@（bundle=%@，Documents/%@ 字母逐字匹配%@，码点=%@）",
                          c.lastPathComponent, bid ?: @"未知", matchedName, isDir ? @"且为目录" : @"(stat 未能确认，但列目录存在)", [codes componentsJoinedByString:@" "]]];
        if (errorText) *errorText = [notes componentsJoinedByString:@"；"];
        return c;
    }

    [notes addObject:[NSString stringWithFormat:@"检查 %lu：wq_list 失败 %lu（其中 wq_stat 直探兜底命中 %lu），均无 Documents/DeltaForce 或 Documents/Delta-Force（字母逐字）",
                      (unsigned long)checked, (unsigned long)listFailed, (unsigned long)statFallback]];
    if (nearHits.count) {
        NSUInteger n = MIN(8, nearHits.count);
        [notes addObject:[NSString stringWithFormat:@"近似名字样本(%lu)：%@",
                          (unsigned long)nearHits.count,
                          [[nearHits subarrayWithRange:NSMakeRange(0, n)] componentsJoinedByString:@", "]]];
    }
    if (errorText) {
        *errorText = [notes componentsJoinedByString:@"；"];
    }
    return nil;
}

// 只接受应用数据容器 Data/Application/<UUID>，排除 PluginKitPlugin / group 容器
// （wq_ls_container_paths 会把插件容器也列出来，它们不是目标）
+ (void)addContainers:(NSArray<NSString *> *)items to:(NSMutableArray<NSString *> *)out seen:(NSMutableSet<NSString *> *)seen {
    for (NSString *c in items) {
        if (![c isKindOfClass:NSString.class] || c.length == 0) continue;
        NSString *parent = [c stringByDeletingLastPathComponent];
        if (![parent isEqualToString:kAppDataRoot]) continue;   // 关键：排除 PluginKitPlugin 等
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
