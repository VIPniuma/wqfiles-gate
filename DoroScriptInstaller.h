//
//  DoroScriptInstaller.h
//  云端脚本落盘：拉到的明文原样 -> 写入 <三角洲容器>/Documents/<特征名>/Saved/LuaSource/。
//  纯逻辑，结果回传，UI 由首页负责。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DoroScriptInstaller : NSObject

// 兜底文件名（仅当服务器没下发文件名时用；正常用服务器下发的原上传名）
+ (NSString *)scriptFileName;

// 服务器明文下发脚本原文，App 逐字节落盘（无加解密）。
// kami/statecode: 当前会话凭证，用于换 token 拉脚本（本方法内部先拉再落盘）。
// completion: (ok, 详细说明)
+ (void)installWithKami:(NSString *)kami
              statecode:(NSString *)statecode
             completion:(void (^)(BOOL ok, NSString *message))completion;

@end

NS_ASSUME_NONNULL_END
