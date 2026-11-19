//
//  DoroCloudToken.h
//  云端脚本换发：用当前卡密 + statecode 生成 ticket -> 服务器领一次性 token
//  -> 用 token 拉加密脚本。纯网络逻辑，结果回传。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DoroCloudToken : NSObject

// 参数集中，不写死在逻辑里
+ (NSString *)serverBase;      // http://118.31.110.187:18443
+ (NSString *)clientHeaderName;
+ (NSString *)clientHeaderValue;
+ (NSString *)ticketSecret;

// 完整链路：kami/statecode 来自 DoroGate 当前会话。
// completion: (ok, message, cipherData, fileName) —— cipherData 是 AES-GCM 密文；
// fileName 是服务器下发的原上传文件名（base64 解码后，原样落盘用）。
+ (void)fetchScriptWithKami:(NSString *)kami
                  statecode:(NSString *)statecode
                 completion:(void (^)(BOOL ok, NSString *message, NSData * _Nullable cipher, NSString * _Nullable fileName))completion;

@end

NS_ASSUME_NONNULL_END
