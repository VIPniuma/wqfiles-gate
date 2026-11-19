//
//  DoroPIP.h
//  画中画模块：用系统公开 AVPictureInPictureController 在退到桌面时显示小窗。
//  点击小窗 -> 系统把工具箱拉回前台并调 onRestore -> 自动拉取脚本并写入。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class AVPlayerLayer;

@interface DoroPIP : NSObject

+ (instancetype)shared;

// 开启画中画（需在用户手势中调用）。returns NO 表示设备/系统不支持或未就绪。
- (BOOL)start;
- (void)stop;
- (BOOL)isActive;

// 点击 PiP 小窗、系统把 App 拉回前台时回调一次（在主队列）。
@property (nonatomic, copy, nullable) void (^onRestore)(void);

@end

NS_ASSUME_NONNULL_END
