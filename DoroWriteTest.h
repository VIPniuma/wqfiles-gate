//
//  DoroWriteTest.h
//  WQ Files + 写入测试
//
//  验证通过后，在当前界面挂一个悬浮测试按钮；点击后走 WQFiles 的
//  worse_query（wq_create_dir / wq_create_file）在 DeltaForce 容器里
//  创建目录并写入测试文件。不改动 WQFiles 原有源码。
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface DoroWriteTest : NSObject

// 在 window 的顶层界面安装测试按钮（验证成功后调用一次）。
+ (void)installIntoWindow:(UIWindow *)window;

@end

NS_ASSUME_NONNULL_END
