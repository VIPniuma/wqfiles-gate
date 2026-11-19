//
//  DoroCloudToken.m
//  云端脚本换发链路（卡密 -> ticket -> token -> 密文）。
//  ticket = HMAC-SHA256(secret, "device_id:minute:kami")，卡密参与签名，
//  服务器不接触卡密明文；换发的 token 一次性、5 分钟过期。
//

#import "DoroCloudToken.h"
#import "T3Verify.h"
#import "DoroStringTable.h"
#import <CommonCrypto/CommonHMAC.h>

@implementation DoroCloudToken

+ (NSString *)serverBase { return DORO_CLOUD_SERVER_BASE; }
+ (NSString *)clientHeaderName { return DORO_CLOUD_HEADER_NAME; }
+ (NSString *)clientHeaderValue { return DORO_CLOUD_HEADER_VALUE; }
+ (NSString *)ticketSecret { return DORO_CLOUD_TICKET_SECRET; }

// HMAC-SHA256 -> 小写十六进制
+ (NSString *)hmacHex:(NSString *)msg key:(NSString *)key {
    const char *k = key.UTF8String;
    const char *m = msg.UTF8String;
    unsigned char digest[CC_SHA256_DIGEST_LENGTH] = {0};
    CCHmac(kCCHmacAlgSHA256, k, strlen(k), m, strlen(m), digest);
    NSMutableString *hex = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) [hex appendFormat:@"%02x", digest[i]];
    return hex;
}

+ (NSURLRequest *)requestWithPath:(NSString *)path headers:(NSDictionary<NSString *,NSString *> *)extra {
    NSURL *url = [NSURL URLWithString:[[self serverBase] stringByAppendingString:path]];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:12];
    [req setValue:[self clientHeaderValue] forHTTPHeaderField:[self clientHeaderName]];
    for (NSString *k in extra) [req setValue:extra[k] forHTTPHeaderField:k];
    return req;
}

+ (void)fetchScriptWithKami:(NSString *)kami
                  statecode:(NSString *)statecode
                 completion:(void (^)(BOOL, NSString *, NSData *, NSString *))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *device = [T3Verify getMachineCode] ?: @"unknown-device";
        NSInteger minute = (NSInteger)(NSDate.date.timeIntervalSince1970 / 60);
        NSString *msg = [NSString stringWithFormat:@"%@:%ld:%@", device, (long)minute, kami];
        NSString *ticket = [self hmacHex:msg key:[self ticketSecret]];

        // 1) 领一次性 token
        NSString *tokenPath = [NSString stringWithFormat:DORO_API_TOKEN_FMT,
                               [self urlEncode:device], ticket, [self urlEncode:kami]];
        NSHTTPURLResponse *tResp = nil;
        NSError *tErr = nil;
        NSData *tData = [NSURLConnection sendSynchronousRequest:[self requestWithPath:tokenPath headers:nil]
                                              returningResponse:&tResp error:&tErr];
        if (!tData) {
            // 把底层原因带出来：ATS 拦截/超时/DNS 各不同，便于定位。
            NSLog(@"[DoroCloudToken] token request failed url=%@ err=%@ code=%ld",
                  tokenPath, tErr.localizedDescription, (long)tErr.code);
            NSString *why = tErr.localizedDescription ?: @"未知网络错误";
            [self finish:completion ok:NO msg:[NSString stringWithFormat:@"连不上验证服务器：%@", why] cipher:nil fileName:nil];
            return;
        }
        NSDictionary *tJson = [NSJSONSerialization JSONObjectWithData:tData options:0 error:nil];
        NSString *token = tJson[@"token"];
        if (!token) {
            NSString *e = tJson[@"error"] ?: @"领取 token 失败";
            [self finish:completion ok:NO msg:e cipher:nil fileName:nil]; return;
        }

        // 2) 用 token 拉脚本（密文）
        NSString *scriptPath = [NSString stringWithFormat:DORO_API_SCRIPT_FMT, [self urlEncode:token]];
        NSHTTPURLResponse *resp = nil;
        NSData *cipher = [NSURLConnection sendSynchronousRequest:[self requestWithPath:scriptPath headers:nil]
                                               returningResponse:&resp error:nil];
        if (resp.statusCode != 200 || !cipher) {
            NSString *msg2 = @"拉取脚本失败";
            NSDictionary *j = [NSJSONSerialization JSONObjectWithData:cipher ?: [NSData data] options:0 error:nil];
            if (j[@"error"]) msg2 = j[@"error"];
            [self finish:completion ok:NO msg:msg2 cipher:nil fileName:nil]; return;
        }
        // 服务器下发的原上传文件名：base64(UTF-8) -> 字符串，逐字符原样
        NSString *nameB64 = [resp valueForHTTPHeaderField:DORO_SCRIPT_NAME_HEADER];
        NSData *nameBytes = [[NSData alloc] initWithBase64EncodedString:nameB64 ?: @"" options:0];
        NSString *fileName = [[NSString alloc] initWithData:nameBytes encoding:NSUTF8StringEncoding];
        if (!fileName.length) fileName = @"script.lua";   // 兜底：服务器没给名字时
        [self finish:completion ok:YES msg:[NSString stringWithFormat:@"拿到脚本原文 %lu 字节", (unsigned long)cipher.length] cipher:cipher fileName:fileName];
    });
}

+ (void)finish:(void (^)(BOOL, NSString *, NSData *, NSString *))completion ok:(BOOL)ok msg:(NSString *)msg cipher:(NSData *)cipher fileName:(NSString *)fileName {
    if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(ok, msg, cipher, fileName); });
}

+ (NSString *)urlEncode:(NSString *)s {
    return [s stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]] ?: s;
}

@end
