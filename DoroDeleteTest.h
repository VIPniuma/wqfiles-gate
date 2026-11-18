//
//  DoroDeleteTest.h
//  删除测试文件：走 worse_query 删除 DeltaForce 容器里的「测试123」。
//  纯逻辑模块，结果通过 completion 回传给首页控制器弹窗。
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface DoroDeleteTest : NSObject

+ (void)runWithHost:(UIViewController *)host
         completion:(void (^)(NSString *title, NSString *message))completion;

@end

NS_ASSUME_NONNULL_END
