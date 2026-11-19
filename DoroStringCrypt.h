//
//  DoroStringCrypt.h
//  字符串混淆运行时解密（编译期字节表在 DoroStringTable.h）。
//  算法与 tools/ipa_hardener/gen_string_table.py 严格对应：
//      plain[i] = cipher[i] ^ KEY ^ (i & 0xFF)
//  密钥集中在外置配置 DoroHardeningConfig.h，本模块不持有明文。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// 传入混淆字节数组与其长度，返回解密后的 NSString；长度 0 返回 @""。
// 复杂度 O(n)，n = length；调用点集中在启动/配置阶段，不在热路径。
NSString *DoroDecrypt(const unsigned char *bytes, NSUInteger length);

NS_ASSUME_NONNULL_END
