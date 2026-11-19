//
//  DoroGate.h
//  首页验证门：T3 卡密验证 + 启动后定时心跳。
//  心跳失败清卡密并推回验证界面；验证通过回调 onSuccess。
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface DoroGate : NSObject

// 全局单例（main.m 创建，首页通过它读卡密/statecode 换 token）。
+ (instancetype)shared;

// window 用于验证框展示与成功后 dismiss。
- (instancetype)initWithWindow:(UIWindow *)window;

// 启动验证（init 后调用一次）：有卡密则静默联网验证，否则弹验证框。
- (void)start;

// 验证成功（主线程），放行功能。
@property (nonatomic, copy, nullable) void (^onSuccess)(void);

// 心跳失败 / 卡密失效（主线程），UI 应锁住功能。
@property (nonatomic, copy, nullable) void (^onInvalid)(NSString *reason);

// 当前会话凭证：卡密与 statecode（心跳 / 云端 token 换发用）。
@property (nonatomic, copy, readonly, nullable) NSString *kami;
@property (nonatomic, copy, readonly, nullable) NSString *statecode;

@end

NS_ASSUME_NONNULL_END
