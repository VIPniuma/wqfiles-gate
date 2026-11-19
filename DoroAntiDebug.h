//
//  DoroAntiDebug.h
//  工具箱自身反调试/反注入（开关见 DoroHardeningConfig.h）。
//  仅作用于本 App 进程，不读写游戏进程内存。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DoroAntiDebug : NSObject

// 在 main() 启动 UIApplicationMain 之前调用一次。检测到调试/注入时终止本进程。
+ (void)install;

@end

NS_ASSUME_NONNULL_END
