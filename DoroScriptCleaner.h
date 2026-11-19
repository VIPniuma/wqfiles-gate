//
//  DoroScriptCleaner.h
//  延迟删除模块：写入脚本后 N 秒自动删掉刚放进去的文件（App 侧默认 2 秒）。
//  纯逻辑，无 UI；由 DoroScriptInstaller 写入成功后调用。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DoroScriptCleaner : NSObject

// delay 秒后删除 path（wq_grant 父目录 + wq_delete + 读回校验）。
// completion 在后台队列回调 (ok, message)；可传 nil。
+ (void)deletePath:(NSString *)path
        afterDelay:(NSTimeInterval)delay
        completion:(void (^ _Nullable)(BOOL ok, NSString *message))completion;

@end

NS_ASSUME_NONNULL_END
