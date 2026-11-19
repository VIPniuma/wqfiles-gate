//
//  DoroStringCrypt.m
//  逐字节异或还原混淆字符串。密钥来自外置 DoroHardeningConfig.h。
//  只读取编译期常量字节，不写任何内存、不碰游戏进程。
//

#import "DoroStringCrypt.h"
#import "DoroHardeningConfig.h"

NSString *DoroDecrypt(const unsigned char *bytes, NSUInteger length)
{
    if (!bytes || length == 0) return @"";
    NSMutableData *buf = [NSMutableData dataWithLength:length];
    unsigned char *out = (unsigned char *)buf.mutableBytes;
    const unsigned char key = (unsigned char)DORO_CRYPT_KEY;
    for (NSUInteger i = 0; i < length; i++) {
        out[i] = bytes[i] ^ key ^ (unsigned char)(i & 0xFF);
    }
    NSString *s = [[NSString alloc] initWithData:buf encoding:NSUTF8StringEncoding];
    return s ?: @"";
}
