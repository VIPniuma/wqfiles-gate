//
//  DoroSBBall.h
//  SpringBoard 悬浮球：在 SpringBoard 进程建独立高层级 window，跨 App / 回桌面都可见。
//  点击触发 DoroSBWriter 写入，toast 显示结果；可拖动。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DoroSBBall : NSObject

+ (instancetype)shared;
- (void)install;   // 幂等：SpringBoard 启动后挂上球

@end

NS_ASSUME_NONNULL_END
