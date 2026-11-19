//
//  DoroScriptInstaller.m
//  1) 用 kami 换 token 拉脚本原文（云端明文下发，无加解密）
//  2) 定位三角洲容器  3) 建 Documents/<真实特征名>/Saved/LuaSource  4) 写文件 + 读回校验。
//  存在性判断一律用读回内容，不用 wq_stat（沙盒下对新建文件假失败）。
//

#import "DoroScriptInstaller.h"
#import "DoroCloudToken.h"
#import "DoroScriptCleaner.h"
#import "DeltaForceLocator.h"
#import "WQAccess.h"
#import "DoroStringTable.h"
#import <sys/stat.h>
#import <errno.h>
#import <stdlib.h>

// 与 DoroWriteTest / DeltaForceLocator 一致：只比 a-z 字母，忽略连接符/大小写/零宽字符。
static NSString * const kFeatureNames[] = { @"DeltaForce", @"Delta-Force" };
static NSString * const kFeatureKey  = @"deltaforce";
static const NSTimeInterval kAutoDeleteDelay = 10.0;   // 写入成功后倒计时：删文件+退出
static NSString * wq_feature_key(NSString *s) {
    if (![s isKindOfClass:NSString.class]) return @"";
    NSMutableString *out = [NSMutableString stringWithCapacity:s.length];
    for (NSUInteger i = 0; i < s.length; i++) {
        unichar ch = [s characterAtIndex:i];
        if (ch >= 'A' && ch <= 'Z') ch = (unichar)(ch + ('a' - 'A'));
        if (ch >= 'a' && ch <= 'z') [out appendFormat:@"%c", (char)ch];
    }
    return out;
}

@implementation DoroScriptInstaller

+ (NSString *)scriptFileName { return @"main.lua"; }

// 找容器 Documents 下真实特征目录名（与 DoroWriteTest.chainForContainer 完全同一套：
// 字母逐字匹配 deltaforce，wq_list 失败则 wq_stat 直探两候选名，最后兜底第一个）。
+ (NSString *)featureNameInContainer:(NSString *)root {
    NSString *docs = [root stringByAppendingPathComponent:@"Documents"];
    wq_grant(root);
    wq_grant(docs);
    NSArray *entries = wq_list(docs, nil);
    NSUInteger count = sizeof(kFeatureNames) / sizeof(kFeatureNames[0]);
    if (entries) {
        for (NSString *n in entries) {
            if ([n isKindOfClass:NSString.class] && [wq_feature_key(n) isEqualToString:kFeatureKey]) return n;
        }
    }
    struct stat st;
    for (NSUInteger i = 0; i < count; i++) {
        NSString *probe = [docs stringByAppendingPathComponent:kFeatureNames[i]];
        if (wq_stat(probe, &st) == 0 && S_ISDIR(st.st_mode)) return kFeatureNames[i];
    }
    return kFeatureNames[0];
}

// 逐级建链 Documents/<真实特征名>/Saved/LuaSource，EEXIST 视为成功。
+ (BOOL)ensureChainFromRoot:(NSString *)root chain:(NSString *)chain error:(NSString **)err {
    struct stat st;
    NSString *cur = root;
    if (wq_stat(cur, &st) != 0 || !S_ISDIR(st.st_mode)) {
        wq_grant([cur stringByDeletingLastPathComponent]);
        NSString *detail = nil;
        if (!wq_create_dir(cur, &detail) && errno != EEXIST) {
            if (err) *err = [NSString stringWithFormat:@"建根失败 %@ errno=%d（%@）", cur, errno, detail ?: @"无"];
            return NO;
        }
    }
    for (NSString *part in [chain componentsSeparatedByString:@"/"]) {
        if (!part.length) continue;
        cur = [cur stringByAppendingPathComponent:part];
        if (wq_stat(cur, &st) == 0 && S_ISDIR(st.st_mode)) continue;
        NSString *detail = nil;
        wq_grant([cur stringByDeletingLastPathComponent]);
        if (!wq_create_dir(cur, &detail) && errno != EEXIST) {
            if (err) *err = [NSString stringWithFormat:@"建目录失败 %@ errno=%d（%@）", cur, errno, detail ?: @"无"];
            return NO;
        }
    }
    return YES;
}

// 写二进制 NSData 到目标：本地临时文件 -> grant 父目录 -> 无条件删旧 -> wq_create_file_from -> 读回校验。
+ (BOOL)writeData:(NSData *)data to:(NSString *)dest error:(NSString **)err {
    NSString *tmp = [NSTemporaryDirectory() stringByAppendingPathComponent:
                     [NSString stringWithFormat:@"doro_script_%llu", (unsigned long long)NSDate.date.timeIntervalSince1970]];
    if (![data writeToFile:tmp atomically:YES]) {
        if (err) *err = @"本地临时文件写入失败";
        return NO;
    }
    NSString *parent = dest.stringByDeletingLastPathComponent;
    wq_grant(parent);
    NSString *delErr = nil;
    wq_delete(dest, &delErr);
    wq_grant(parent);
    NSString *detail = nil;
    BOOL createOK = wq_create_file_from(dest, tmp, &detail);
    [[NSFileManager defaultManager] removeItemAtPath:tmp error:nil];

    // 读回校验：wq_stat 会假失败，以读回字节为准
    wq_grant(parent);
    NSData *onDisk = [NSData dataWithContentsOfFile:dest];
    BOOL verified = onDisk && [onDisk isEqualToData:data];
    if (verified) return YES;
    if (err) {
        *err = [NSString stringWithFormat:@"落盘校验失败 create=%@（%@）\n目标=%@\n读回=%lu字节(期望%lu)",
                createOK ? @"OK" : @"失败", detail ?: @"无", dest,
                (unsigned long)onDisk.length, (unsigned long)data.length];
    }
    return NO;
}

+ (void)installWithKami:(NSString *)kami
              statecode:(NSString *)statecode
             completion:(void (^)(BOOL, NSString *))completion {
    // 1) 拉脚本原文（DoroCloudToken 内部切全局队列、completion 回主队列，这里用嵌套 block 避免信号量死锁）
    [DoroCloudToken fetchScriptWithKami:kami statecode:statecode completion:^(BOOL fetchOK, NSString *fetchMsg, NSData *scriptData, NSString *fileName) {
        if (!fetchOK || !scriptData) {
            [self done:completion ok:NO msg:fetchMsg ?: @"拉取脚本失败"]; return;
        }
        // 后续定位/落盘都在后台队列做；scriptData 即服务器上传的原文，逐字节落盘
        NSData *plain = scriptData;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            // 2) 定位 Saved root
            NSString *diag = nil;
            NSString *saved = [DeltaForceLocator findSavedRoot:&diag];
            if (!saved.length) {
                [self done:completion ok:NO msg:[NSString stringWithFormat:@"未找到三角洲容器：%@", diag ?: @""]]; return;
            }

            // 3) 建完整链 Documents/<真实特征名>/Saved/LuaSource（与测试文本同一套识别+建链）
            NSString *feature = [self featureNameInContainer:saved];
            NSString *chain = [NSString stringWithFormat:DORO_LUA_CHAIN_FMT, feature];
            NSString *err = nil;
            if (![self ensureChainFromRoot:saved chain:chain error:&err]) {
                [self done:completion ok:NO msg:err]; return;
            }
            NSString *luaDir = [saved stringByAppendingPathComponent:chain];

            // 4) 写文件 + 读回校验（文件名用服务器下发的原上传名，原样保留）
            NSString *finalName = fileName.length ? fileName : [self scriptFileName];
            NSString *dest = [luaDir stringByAppendingPathComponent:finalName];
            if (![self writeData:plain to:dest error:&err]) {
                [self done:completion ok:NO msg:err]; return;
            }
            // 写入成功 -> 10 秒倒计时：删文件 + 退出工具箱
            [DoroScriptCleaner deletePath:dest afterDelay:kAutoDeleteDelay completion:^(BOOL ok __unused, NSString *message __unused) {
                exit(0);   // 退出工具箱 App 自身
            }];
            // 按要求：成功提示只显示「写入成功」，不暴露目录/文件名/字节等实际情况
            [self done:completion ok:YES msg:@"写入成功"];
        });
    }];
}

+ (void)done:(void (^)(BOOL, NSString *))completion ok:(BOOL)ok msg:(NSString *)msg {
    if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(ok, msg); });
}

@end
