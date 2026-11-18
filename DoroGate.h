//
//  DoroGate.h
//  WQ Files + 启动验证
//
//  首页验证门：安装 T3 验证 SDK，在指定 VC 上弹出验证页。
//  只依赖 T3SDK；不改动 WQFiles 任何原有源码。
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface DoroGate : NSObject

// 安装启动验证：初始化 SDK，若有本地卡密先静默登录，否则弹验证页。
// window 用于验证成功后 dismiss 顶层弹窗。
- (instancetype)initWithWindow:(UIWindow *)window;

// 验证成功回调（主线程），在这里放行主界面功能。
@property (nonatomic, copy, nullable) void (^onSuccess)(void);

@end

NS_ASSUME_NONNULL_END
