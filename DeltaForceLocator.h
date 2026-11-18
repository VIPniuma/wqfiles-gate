//
//  DeltaForceLocator.h
//  doro工具箱
//
//  动态定位 DeltaForce（三角洲行动）数据容器里的 Saved 目录。
//  容器 UUID 是设备/安装相关的，写死会在别人手机上失效，必须运行时发现。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DeltaForceLocator : NSObject

// 返回 <容器>/Documents/DeltaForce/Saved 的绝对路径；找不到返回 nil。
// errorText 带回诊断：枚举了多少容器、LaunchServices 是否可读、兜底结果。
// 注意：内部会调用 wq_load_display_names()，首次可能较慢，请在后台线程调用。
+ (nullable NSString *)findSavedRoot:(NSString * _Nullable * _Nullable)errorText;

@end

NS_ASSUME_NONNULL_END
