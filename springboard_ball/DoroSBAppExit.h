//
//  DoroSBAppExit.h
//  从 SpringBoard 退出指定的 App（按 Bundle ID）。写入成功后 2 秒倒计时结束时调用。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DoroSBAppExit : NSObject

// 通过 LSApplicationWorkspace 强制退出 bundleID 对应的运行进程；未运行则无事发生。
+ (void)terminateBundle:(NSString *)bundleID;

@end

NS_ASSUME_NONNULL_END
