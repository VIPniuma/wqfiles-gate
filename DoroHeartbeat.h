//
//  DoroHeartbeat.h
//  卡密心跳：用 T3 自带的 heartbeatWithKami 定时保活。
//  失败（单次）立即回调 onFailure，由调用方推回卡密验证界面。
//

#import <Foundation/Foundation.h>

@class T3Verify;

NS_ASSUME_NONNULL_BEGIN

@interface DoroHeartbeat : NSObject

// verify: 已 init 的 T3 实例；kami: 卡密；statecode: 登录返回的会话码；
// interval: 心跳间隔秒；onFailure: 失败回调（主线程）。
- (instancetype)initWithVerify:(T3Verify *)verify
                          kami:(NSString *)kami
                     statecode:(NSString *)statecode
                      interval:(NSTimeInterval)interval
                     onFailure:(void (^)(NSString *reason))onFailure;

- (void)start;
- (void)stop;

@end

NS_ASSUME_NONNULL_END
