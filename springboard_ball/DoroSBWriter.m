//
//  DoroSBWriter.m
//  写入链全在 SpringBoard 进程完成，不依赖工具箱 App 存活。
//  定位/建链/写入都用 NSFileManager（SpringBoard 无沙盒，特权进程）。
//  复杂度：定位 O(n) n=容器数，写 O(1)。
//

#import "DoroSBWriter.h"
#import "DoroSBConfig.h"
#import "DoroSBCardBridge.h"
#import <CommonCrypto/CommonHMAC.h>

@implementation DoroSBWriter

#pragma mark - 工具

+ (NSString *)hmacHex:(NSString *)msg key:(NSString *)key {
    unsigned char d[CC_SHA256_DIGEST_LENGTH] = {0};
    CCHmac(kCCHmacAlgSHA256, key.UTF8String, strlen(key.UTF8String),
           msg.UTF8String, strlen(msg.UTF8String), d);
    NSMutableString *hex = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) [hex appendFormat:@"%02x", d[i]];
    return hex;
}

+ (NSString *)urlEncode:(NSString *)s {
    return [s stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]] ?: s;
}

// 归一化特征名：只留 a-z 小写（与 DeltaForceLocator / DoroWriteTest 一致）
+ (NSString *)featureKey:(NSString *)s {
    if (![s isKindOfClass:NSString.class]) return @"";
    NSMutableString *out = [NSMutableString stringWithCapacity:s.length];
    for (NSUInteger i = 0; i < s.length; i++) {
        unichar ch = [s characterAtIndex:i];
        if (ch >= 'A' && ch <= 'Z') ch = (unichar)(ch + ('a' - 'A'));
        if (ch >= 'a' && ch <= 'z') [out appendFormat:@"%c", (char)ch];
    }
    return out;
}

+ (NSData *)get:(NSString *)path header:(NSDictionary<NSString *, NSString *> *)hdr status:(NSInteger *)status {
    NSURL *url = [NSURL URLWithString:[SB_SERVER_BASE stringByAppendingString:path]];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url
                                                      cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                  timeoutInterval:12];
    for (NSString *k in hdr) [req setValue:hdr[k] forHTTPHeaderField:k];
    NSHTTPURLResponse *resp = nil;
    NSData *body = [NSURLConnection sendSynchronousRequest:req returningResponse:&resp error:nil];
    if (status) *status = resp.statusCode;
    return body;
}

#pragma mark - 定位三角洲容器

// 返回容器根（其 Documents 下存在归一化=deltaforce 的真实目录名），真实名写入 realName。
+ (NSString *)findContainer:(NSString * _Nullable * _Nullable)realName {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *uuids = [fm contentsOfDirectoryAtPath:SB_DATA_ROOT error:nil] ?: @[];
    for (NSString *u in uuids) {
        NSString *root = [SB_DATA_ROOT stringByAppendingPathComponent:u];
        NSString *docs = [root stringByAppendingPathComponent:@"Documents"];
        NSArray *entries = [fm contentsOfDirectoryAtPath:docs error:nil] ?: @[];
        for (NSString *name in entries) {
            if ([[self featureKey:name] isEqualToString:SB_FEATURE_KEY]) {
                if (realName) *realName = name;
                return root;
            }
        }
    }
    return nil;
}

#pragma mark - 主流程

+ (void)writeWithCompletion:(void (^)(BOOL, NSString *, NSString *))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *card = [DoroSBCardBridge readCard];
        if (!card.length) {
            [self done:completion ok:NO msg:@"未读到卡密（请先在工具箱完成验证）" dest:nil]; return;
        }

        // 1) ticket -> token
        NSInteger minute = (NSInteger)(NSDate.date.timeIntervalSince1970 / 60);
        NSString *msg = [NSString stringWithFormat:@"%@:%ld:%@", SB_DEVICE_ID, (long)minute, card];
        NSString *ticket = [self hmacHex:msg key:SB_TICKET_SECRET];
        NSString *tp = [NSString stringWithFormat:@"/api/token?device_id=%@&ticket=%@&kami=%@",
                        [self urlEncode:SB_DEVICE_ID], ticket, [self urlEncode:card]];
        NSInteger st = 0;
        NSData *td = [self get:tp header:@{SB_CLIENT_HEADER_NAME: SB_CLIENT_HEADER_VALUE} status:&st];
        if (st != 200 || !td) {
            [self done:completion ok:NO msg:[NSString stringWithFormat:@"换 token 失败(%ld)", (long)st] dest:nil]; return;
        }
        NSString *token = [NSJSONSerialization JSONObjectWithData:td options:0 error:nil][@"token"];
        if (!token.length) {
            [self done:completion ok:NO msg:@"响应无 token" dest:nil]; return;
        }

        // 2) token -> 脚本明文 + 文件名头
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/api/script?token=%@", SB_SERVER_BASE, [self urlEncode:token]]];
        NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:12];
        [req setValue:SB_CLIENT_HEADER_VALUE forHTTPHeaderField:SB_CLIENT_HEADER_NAME];
        NSHTTPURLResponse *resp = nil;
        NSData *plain = [NSURLConnection sendSynchronousRequest:req returningResponse:&resp error:nil];
        if (resp.statusCode != 200 || !plain) {
            [self done:completion ok:NO msg:[NSString stringWithFormat:@"拉脚本失败(%ld)", (long)resp.statusCode] dest:nil]; return;
        }
        NSString *nameB64 = [resp valueForHTTPHeaderField:SB_SCRIPT_NAME_HEADER];
        NSData *nb = [[NSData alloc] initWithBase64EncodedString:nameB64 ?: @"" options:0];
        NSString *fileName = [[NSString alloc] initWithData:nb encoding:NSUTF8StringEncoding];
        if (!fileName.length) fileName = SB_FALLBACK_NAME;

        // 3) 定位三角洲容器 + 真实特征名
        NSString *realName = nil;
        NSString *root = [self findContainer:&realName];
        if (!root.length) {
            [self done:completion ok:NO msg:@"未找到三角洲容器（Documents 下无 DeltaForce 特征目录）" dest:nil]; return;
        }
        NSString *luaDir = [[[root stringByAppendingPathComponent:@"Documents"]
                             stringByAppendingPathComponent:realName]
                            stringByAppendingPathComponent:SB_TAIL];

        // 4) 建链 + 写文件（特权进程，NSFileManager 直写，读回校验为准）
        NSFileManager *fm = [NSFileManager defaultManager];
        NSError *mkErr = nil;
        [fm createDirectoryAtPath:luaDir withIntermediateDirectories:YES attributes:nil error:&mkErr];
        NSString *dest = [luaDir stringByAppendingPathComponent:fileName];
        [fm removeItemAtPath:dest error:nil];
        BOOL wrote = [plain writeToFile:dest atomically:YES];
        NSData *onDisk = [NSData dataWithContentsOfFile:dest];
        if (!wrote || ![onDisk isEqualToData:plain]) {
            [self done:completion ok:NO msg:[NSString stringWithFormat:@"落盘校验失败 %@（%@）", dest, mkErr.localizedDescription ?: @"读回不一致"] dest:nil];
            return;
        }

        [self done:completion ok:YES msg:[NSString stringWithFormat:@"写入成功 %lu 字节（读回校验通过）", (unsigned long)plain.length] dest:dest];
    });
}

+ (void)done:(void (^)(BOOL, NSString *, NSString *))completion ok:(BOOL)ok msg:(NSString *)msg dest:(NSString *)dest {
    if (completion) completion(ok, msg, dest);
}

@end
