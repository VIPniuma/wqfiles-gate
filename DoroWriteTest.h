//
//  DoroWriteTest.h
//  生成测试文件：走 worse_query 在 DeltaForce 容器里创建目录并写入测试文件。
//  纯逻辑模块，不含 UI；结果通过 completion 回传给首页控制器弹窗。
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface DoroWriteTest : NSObject

// host 仅用于保留调用语义；结果以 (标题, 正文) 回传，UI 由调用方负责。
+ (void)runWithHost:(UIViewController *)host
         completion:(void (^)(NSString *title, NSString *message))completion;

@end

NS_ASSUME_NONNULL_END
