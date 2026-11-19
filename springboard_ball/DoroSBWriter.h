//
//  DoroSBWriter.h
//  SpringBoard 侧写入链：卡密 -> ticket -> token -> 脚本明文 -> 定位三角洲容器 ->
//  写 Documents/<特征名>/Saved/LuaSource/<上传原名> -> 读回校验。
//  成功后回传落盘完整路径；删除/关球/退出由悬浮球模块在 2 秒倒计时后统一执行。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DoroSBWriter : NSObject

// completion: (ok, message, destPath) —— destPath 为写入文件的完整路径（失败时 nil）。
+ (void)writeWithCompletion:(void (^ _Nullable)(BOOL ok, NSString *message, NSString * _Nullable destPath))completion;

@end

NS_ASSUME_NONNULL_END
