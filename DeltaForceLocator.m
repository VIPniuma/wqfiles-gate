//
//  DeltaForceLocator.m
//  复刻自黑猫工具箱 WQGameScanApps (Mach-O 0x10003ac78)
//
//  识别算法（纯特征，不写死 UUID / 不依赖 bundle id 可读）：
//   1) 收集所有数据容器（UUID 目录名）：
//      - wq_ls_container_paths（LaunchServices 数据库）
//      - wq_list(/private/var/mobile/Containers/Data/Application)
//      - wq_enumerate（fsgetpath 扫 inode，不受沙盒目录列表限制）
//   2) 逐个容器：wq_list 列出 Documents 下真实条目名，用区分大小写的
//      isEqualToString:@"DeltaForce" 精确匹配（一个字母都不能差），再 wq_stat 确认是目录。
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

// 严格特征目录名：字母逐字匹配 DeltaForce（大小写不敏感，因 iOS 目录大小写不敏感；
// 但字母本身一个都不能差，Delta-Force / DeltaXForce 都不算）。
static NSString * const kFeatureName  = @"DeltaForce";
static NSString * const kDocsRel      = @"Documents";
static NSString * const kFeatureRel   = @"Documents/DeltaForce";  // 仅显示用
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

    // 2) 严格检查：列出 Documents 真实条目名 → 逐字精确匹配 Delta-Force / DeltaForce → 确认是目录
    struct stat st;
    NSUInteger checked = 0, listFailed = 0;
    for (NSString *c in containers) {
        if (![c isKindOfClass:NSString.class] || c.length == 0) continue;
        checked++;
        NSString *docs = [c stringByAppendingPathComponent:kDocsRel];
        // 先拿容器 token 再列：wq_list 内部只 grant(docs)，容器根未授权时仍会失败
        wq_grant(c);
        wq_grant(docs);
        NSString *listErr = nil;
        NSArray *entries = wq_list(docs, &listErr);   // Documents 下的真实名字（不走大小写折叠）
        if (!entries) { listFailed++; continue; }

        BOOL nameMatch = NO;
        NSString *matchedName = nil;
        for (NSString *name in entries) {
            if (![name isKindOfClass:NSString.class]) continue;
            // 字母逐字比对、仅忽略大小写：DeltaForce 的任意大小写变体算命中；
            // Delta-Force / DeltaXForce 等字母不同的都不算。
            if ([name caseInsensitiveCompare:kFeatureName] == NSOrderedSame) {
                nameMatch = YES; matchedName = name; break;
            }
        }
        if (!nameMatch) continue;

        NSString *feature = [docs stringByAppendingPathComponent:matchedName];
        if (wq_stat(feature, &st) != 0 || !S_ISDIR(st.st_mode)) continue;

        // 把命中名的 Unicode 码点打出来，若有隐藏字符一眼可见
        NSMutableArray *codes = [NSMutableArray array];
        for (NSUInteger i = 0; i < matchedName.length; i++) {
            [codes addObject:[NSString stringWithFormat:@"%04X", [matchedName characterAtIndex:i]]];
        }
        NSString *bid = [self labelForContainer:c];
        wq_grant(c);   // 拿容器 token，返回容器根（token 精确覆盖）
        [notes addObject:[NSString stringWithFormat:@"严格命中容器 %@（bundle=%@，Documents/%@ 字母逐字匹配且为目录，码点=%@）",
                          c.lastPathComponent, bid ?: @"未知", matchedName, [codes componentsJoinedByString:@" "]]];
        if (errorText) *errorText = [notes componentsJoinedByString:@"；"];
        return c;
    }

    [notes addObject:[NSString stringWithFormat:@"检查 %lu：Documents 列不出 %lu，均无 Documents/%@（字母逐字）目录",
                      (unsigned long)checked, (unsigned long)listFailed, kFeatureName]];
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
