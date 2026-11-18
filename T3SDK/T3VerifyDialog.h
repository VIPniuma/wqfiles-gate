/**
 * 网络验证 iOS 弹窗验证组件
 * 官网: https://www.t3yanzheng.com
 *
 * 功能：公告显示、版本号判断、卡密输入登录
 * 依赖: UIKit + T3Verify SDK
 *
 * 使用方法:
 *   T3VerifyDialog *dialog = [[T3VerifyDialog alloc] initWithVerify:verify
 *                                                     localVersion:@"1000"];
 *   dialog.onLoginSuccess = ^(T3LoginResult *result) {
 *       // 验证通过，进入主界面
 *   };
 *   [dialog showInViewController:self];
 */

#import <UIKit/UIKit.h>
#import "T3Verify.h"

NS_ASSUME_NONNULL_BEGIN

typedef void(^T3VerifyLoginSuccessBlock)(T3LoginResult *result, NSString *card, NSString *stateCode);

@interface T3VerifyDialog : NSObject

@property (nonatomic, copy, nullable) T3VerifyLoginSuccessBlock onLoginSuccess;

- (instancetype)initWithVerify:(T3Verify *)verify
                  localVersion:(NSString *)localVersion;

/// 在指定 ViewController 上显示验证弹窗
- (void)showInViewController:(UIViewController *)viewController;

@end

NS_ASSUME_NONNULL_END
