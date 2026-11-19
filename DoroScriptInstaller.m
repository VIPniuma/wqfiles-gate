//
//  DoroScriptInstaller.m
//  1) 用 kami 换 token 拉密文  2) AES-GCM 解密成 Lua 明文
//  3) 定位三角洲容器 Saved  4) 建 LuaSource  5) 写文件 + 读回校验。
//  存在性判断一律用读回内容，不用 wq_stat（沙盒下对新建文件假失败）。
//

#import "DoroScriptInstaller.h"
#import "DoroCloudToken.h"
#import "DeltaForceLocator.h"
#import "WQAccess.h"
#import "T3Verify.h"
#import <CommonCrypto/CommonCrypto.h>
#import <CommonCrypto/CommonHMAC.h>
#import <sys/stat.h>
#import <errno.h>

@implementation DoroScriptInstaller

+ (NSString *)masterKeyBase64 { return @"iXHnFltefyBRuDuJQty2bitkiOrsyzbuCnDB5oNJFy0="; }
+ (NSString *)scriptFileName { return @"main.lua"; }

// HMAC-SHA256(master, device_id) -> 32 字节密钥（与服务端 script_crypto._derive_key 一致）
+ (NSData *)deriveKeyForDevice:(NSString *)device {
    NSData *master = [[NSData alloc] initWithBase64EncodedString:[self masterKeyBase64] options:0];
    NSMutableData *out = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA256, master.bytes, master.length,
           device.UTF8String, strlen(device.UTF8String), out.mutableBytes);
    return out;
}

// blob = 12字节nonce + (ciphertext || 16字节tag)；用 GCM 解密，返回明文 NSData。
+ (NSData *)decryptBlob:(NSData *)blob device:(NSString *)device {
    if (blob.length < 12 + 16) return nil;
    const uint8_t *bytes = blob.bytes;
    NSData *nonce = [blob subdataWithRange:NSMakeRange(0, 12)];
    NSUInteger ctLen = blob.length - 12 - 16;
    NSData *ct = [blob subdataWithRange:NSMakeRange(12, ctLen)];
    NSData *tag = [blob subdataWithRange:NSMakeRange(blob.length - 16, 16)];

    NSData *key = [self deriveKeyForDevice:device];
    NSMutableData *plain = [NSMutableData dataWithLength:ctLen];
    CCCryptorStatus st = CCCryptorGCMOneshotDecrypt(kCCAlgorithmAES,
                                                    key.bytes, key.length,
                                                    nonce.bytes, nonce.length,
                                                    NULL, 0,
                                                    ct.bytes, ctLen,
                                                    plain.mutableBytes, ctLen,
                                                    (void *)tag.bytes, tag.length);
    if (st != kCCSuccess) {
        NSLog(@"[Installer] GCM decrypt failed status=%d", st);
        return nil;
    }
    return plain;
}

// 建链：保证 <savedRoot>/LuaSource 存在。EEXIST 视为成功。
+ (BOOL)ensureDir:(NSString *)dir error:(NSString **)err {
    struct stat st;
    if (wq_stat(dir, &st) == 0 && S_ISDIR(st.st_mode)) return YES;
    wq_grant([dir stringByDeletingLastPathComponent]);
    NSString *detail = nil;
    if (!wq_create_dir(dir, &detail) && errno != EEXIST) {
        if (err) *err = [NSString stringWithFormat:@"建目录失败 %@ errno=%d（%@）", dir, errno, detail ?: @"无"];
        return NO;
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
    // 1) 拉密文（DoroCloudToken 内部切全局队列、completion 回主队列，这里用嵌套 block 避免信号量死锁）
    [DoroCloudToken fetchScriptWithKami:kami statecode:statecode completion:^(BOOL fetchOK, NSString *fetchMsg, NSData *cipher, NSString *fileName) {
        if (!fetchOK || !cipher) {
            [self done:completion ok:NO msg:fetchMsg ?: @"拉取脚本失败"]; return;
        }
        // 后续解密/定位/落盘都在后台队列做
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            // 2) 解密（device_id 必须与服务端加密时一致：getMachineCode）
            NSString *device = [T3Verify getMachineCode] ?: @"unknown-device";
            NSData *plain = [self decryptBlob:cipher device:device];
            if (!plain) {
                [self done:completion ok:NO msg:@"脚本解密失败（主密钥或设备码不匹配）"]; return;
            }

            // 3) 定位 Saved root
            NSString *diag = nil;
            NSString *saved = [DeltaForceLocator findSavedRoot:&diag];
            if (!saved.length) {
                [self done:completion ok:NO msg:[NSString stringWithFormat:@"未找到三角洲容器：%@", diag ?: @""]]; return;
            }

            // 4) 建 LuaSource 目录
            NSString *luaDir = [saved stringByAppendingPathComponent:@"LuaSource"];
            NSString *err = nil;
            if (![self ensureDir:luaDir error:&err]) {
                [self done:completion ok:NO msg:err]; return;
            }

            // 5) 写文件 + 读回校验（文件名用服务器下发的原上传名，原样保留）
            NSString *finalName = fileName.length ? fileName : [self scriptFileName];
            NSString *dest = [luaDir stringByAppendingPathComponent:finalName];
            if (![self writeData:plain to:dest error:&err]) {
                [self done:completion ok:NO msg:err]; return;
            }
            [self done:completion ok:YES msg:[NSString stringWithFormat:@"落盘成功\n目录：%@\n文件名：%@\n明文 %lu 字节（读回校验通过）",
                                              luaDir, finalName, (unsigned long)plain.length]];
        });
    }];
}

+ (void)done:(void (^)(BOOL, NSString *))completion ok:(BOOL)ok msg:(NSString *)msg {
    if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(ok, msg); });
}

@end
