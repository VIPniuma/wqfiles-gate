//
//  DoroWriteTest.m
//  生成测试文件（纯逻辑，UI 由 DoroHomeViewController 负责）。
//  流程复刻自黑猫工具箱：安全相对路径校验 → 逐级建链 → wq_create_file_from 写入 → wq_stat 校验。
//  目标：<DeltaForce容器>/Documents/<特征名>/Saved/LuaDebug/LuaSource/DFM/BusinessEntrance/测试123
//  复杂度 O(k)，k = 路径级数。
//

#import "DoroWriteTest.h"
#import "DeltaForceLocator.h"
#import "WQAccess.h"
#import <sys/stat.h>
#import <errno.h>

static NSString * const kFeatureNames[] = { @"DeltaForce", @"Delta-Force" };
static NSString * const kFeatureKey  = @"deltaforce";
static NSString * const kTail = @"Saved/LuaDebug/LuaSource/DFM/BusinessEntrance";
static NSString * const kFile = @"测试123";
static NSString * const kBody = @"测试123";

// 与 DeltaForceLocator 一致：只比 a-z 字母，忽略连接符/空格/大小写。
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

@implementation DoroWriteTest

// 按容器下真实存在的特征目录名构建链；wq_list 失败时用 wq_stat 直探两候选名。
+ (NSString *)chainForContainer:(NSString *)root {
    NSString *docs = [root stringByAppendingPathComponent:@"Documents"];
    wq_grant(root); wq_grant(docs);
    NSArray *entries = wq_list(docs, nil);
    NSUInteger count = sizeof(kFeatureNames) / sizeof(kFeatureNames[0]);
    NSString *name = kFeatureNames[0];
    struct stat st;
    if (entries) {
        for (NSString *n in entries) {
            if ([n isKindOfClass:NSString.class] && [wq_feature_key(n) isEqualToString:kFeatureKey]) {
                name = n; break;
            }
        }
    } else {
        for (NSUInteger i = 0; i < count; i++) {
            NSString *probe = [docs stringByAppendingPathComponent:kFeatureNames[i]];
            if (wq_stat(probe, &st) == 0 && S_ISDIR(st.st_mode)) { name = kFeatureNames[i]; break; }
        }
    }
    return [NSString stringWithFormat:@"Documents/%@/%@", name, kTail];
}

+ (void)runWithHost:(UIViewController * __unused)host
         completion:(void (^)(NSString *, NSString *))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *diag = nil;
        NSString *root = [DeltaForceLocator findSavedRoot:&diag];
        NSString *title, *msg;
        if (!root) {
            title = @"未找到三角洲容器";
            msg = diag ?: @"未知原因";
        } else {
            NSString *chain = [self chainForContainer:root];
            if (![self safeRelative:chain]) {
                title = @"路径校验失败";
                msg = @"相对路径含非法成分";
            } else {
                NSString *err = nil;
                NSUInteger made = 0;
                BOOL ok = [self ensureChainFromRoot:root chain:chain made:&made error:&err];
                if (!ok) {
                    title = @"创建目录失败";
                    msg = err ?: @"未知原因";
                } else {
                    NSString *target = [root stringByAppendingPathComponent:chain];
                    NSString *file = [target stringByAppendingPathComponent:kFile];
                    BOOL wok = [self writeFile:file error:&err];   // 内部已做实读校验
                    title = wok ? @"生成成功" : @"写入文件失败";
                    msg = wok
                        ? [NSString stringWithFormat:@"目录：%@\n文件：%@\n新建目录：%lu 级\n读回校验：通过",
                           target, file, (unsigned long)made]
                        : (err ?: @"未知原因");
                }
            }
        }
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(title, msg); });
    });
}

// 不以 / 开头、不含 .. 成分
+ (BOOL)safeRelative:(NSString *)rel {
    if (rel.length == 0 || [rel hasPrefix:@"/"]) return NO;
    for (NSString *part in [rel componentsSeparatedByString:@"/"]) {
        if ([part isEqualToString:@".."] || [part isEqualToString:@"."]) return NO;
    }
    return YES;
}

// 逐级 wq_stat，缺失才 wq_create_dir；EEXIST 视为成功（stat 被沙盒挡但目录存在）。
+ (BOOL)ensureChainFromRoot:(NSString *)root chain:(NSString *)chain made:(NSUInteger *)made error:(NSString **)err {
    struct stat st;
    NSString *cur = root;
    if (wq_stat(cur, &st) != 0 || !S_ISDIR(st.st_mode)) {
        wq_grant([cur stringByDeletingLastPathComponent]);
        NSString *detail = nil;
        if (!wq_create_dir(cur, &detail) && errno != EEXIST) {
            if (err) *err = [NSString stringWithFormat:@"建根失败 path=%@ errno=%d（%@）", cur, errno, detail ?: @"无"];
            return NO;
        }
        if (made) (*made)++;
    }
    for (NSString *part in [chain componentsSeparatedByString:@"/"]) {
        if (part.length == 0) continue;
        cur = [cur stringByAppendingPathComponent:part];
        if (wq_stat(cur, &st) == 0 && S_ISDIR(st.st_mode)) continue;
        NSString *detail = nil;
        if (!wq_create_dir(cur, &detail) && errno != EEXIST) {
            if (err) *err = [NSString stringWithFormat:@"建目录失败 path=%@ errno=%d（%@）", cur, errno, detail ?: @"无"];
            return NO;
        }
        if (made) (*made)++;
    }
    return YES;
}

// 本地沙盒落临时文件 → 无条件删旧（O_EXCL 需要目标不存在）→ wq_create_file_from 流式写 → 实读校验。
// 返回值以"文件真实存在且内容正确"为准，不轻信 wq_create_file_from 的布尔值。
+ (BOOL)writeFile:(NSString *)dest error:(NSString **)err {
    NSString *tmp = [NSTemporaryDirectory() stringByAppendingPathComponent:
                     [NSString stringWithFormat:@"doro_write_%llu", (unsigned long long)NSDate.date.timeIntervalSince1970]];
    if (![kBody writeToFile:tmp atomically:YES encoding:NSUTF8StringEncoding error:nil]) {
        if (err) *err = @"本地临时文件写入失败";
        return NO;
    }
    NSString *parent = dest.stringByDeletingLastPathComponent;
    wq_grant(parent);

    // 不依赖 wq_stat 判断存在与否（沙盒下会假失败）：无条件删一次，忽略"本来就不存在"。
    NSString *delErr = nil;
    wq_delete(dest, &delErr);
    wq_grant(parent);   // 删除可能消费掉 token，重新授权父目录再建

    NSString *detail = nil;
    BOOL createOK = wq_create_file_from(dest, tmp, &detail);
    [[NSFileManager defaultManager] removeItemAtPath:tmp error:nil];

    // 实读校验：grant 父目录后用 [NSString stringWithContentsOfFile] 读真实内容。
    wq_grant(parent);
    NSString *onDisk = [NSString stringWithContentsOfFile:dest encoding:NSUTF8StringEncoding error:nil];
    BOOL verified = [onDisk isEqualToString:kBody];
    struct stat st;
    BOOL statOK = wq_stat(dest, &st) == 0 && S_ISREG(st.st_mode) && st.st_size > 0;

    if (verified && statOK) return YES;
    if (err) {
        *err = [NSString stringWithFormat:@"写入未落盘：create=%@（%@）\nstat=%@ size=%lld\n读回=%@\npath=%@",
                createOK ? @"OK" : @"失败", detail ?: @"无",
                statOK ? @"OK" : @"失败", statOK ? (long long)st.st_size : -1LL,
                onDisk ? [NSString stringWithFormat:@"'%@'", onDisk] : @"读不到", dest];
    }
    return NO;
}

@end
