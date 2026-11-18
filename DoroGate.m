//
//  DoroGate.m
//  WQ Files + 启动验证
//
//  验证逻辑复用已在最小工程真机验证过的 T3SDK：
//   initRsa → 本地卡密自动登录 → 失败则弹 T3VerifyDialog。
//  T3VerifyDialog 是 NSObject，必须走 showInViewController:。
//

#import "DoroGate.h"
#import "T3Verify.h"
#import "T3VerifyDialog.h"
#import "T3GateConfig.h"

@interface DoroGate ()
@property (nonatomic, strong) T3Verify *verify;
@property (nonatomic, strong) T3VerifyDialog *dialog;
@property (nonatomic, weak) UIWindow *window;
@end

@implementation DoroGate

- (instancetype)initWithWindow:(UIWindow *)window {
    if ((self = [super init])) {
        _window = window;
    }
    return self;
}

- (void)start {
    self.verify = [[T3Verify alloc] init];
    NSError *err = nil;
    BOOL ok = [self.verify initRsaWithLoginCode:T3_LOGIN_CODE
                                    noticeCode:T3_NOTICE_CODE
                                   versionCode:T3_VERSION_CODE
                                 heartbeatCode:T3_HEARTBEAT_CODE
                                        appkey:T3_APPKEY
                                  rsaPublicKey:T3_RSA_PUBLIC_KEY
                                         error:&err];
    NSLog(@"[DoroGate] SDK init=%d err=%@", ok, err.localizedDescription);

    NSString *saved = [[NSUserDefaults standardUserDefaults] stringForKey:T3_PREF_KEY_CARD];
    if (saved.length) {
        [self autoLogin:saved];
    } else {
        [self showGate];
    }
}

- (void)showGate {
    self.dialog = [[T3VerifyDialog alloc] initWithVerify:self.verify localVersion:T3_LOCAL_VERSION];
    __weak typeof(self) wf = self;
    self.dialog.onLoginSuccess = ^(T3LoginResult *result __unused, NSString *card, NSString *stateCode __unused) {
        [[NSUserDefaults standardUserDefaults] setObject:card forKey:T3_PREF_KEY_CARD];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [wf onVerified];
    };
    // 延后一拍，等 rootVC 已经 present 出来再弹，避免启动时序问题
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIViewController *top = [self topViewController];
        if (!top) return;
        [wf.dialog showInViewController:top];
    });
}

- (void)autoLogin:(NSString *)card {
    NSString *machine = [T3Verify getMachineCode];
    __weak typeof(self) wf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        T3LoginResult *r = [wf.verify loginWithKami:card imei:machine];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (r.success) {
                [wf onVerified];
            } else {
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:T3_PREF_KEY_CARD];
                [[NSUserDefaults standardUserDefaults] synchronize];
                [wf showGate];
            }
        });
    });
}

- (void)onVerified {
    UIViewController *top = [self topViewController];
    while (top.presentedViewController) top = top.presentedViewController;
    if (top.presentingViewController) [top dismissViewControllerAnimated:YES completion:nil];
    self.dialog = nil;
    NSLog(@"[DoroGate] 验证成功");
    if (self.onSuccess) self.onSuccess();
}

- (UIViewController *)topViewController {
    UIViewController *top = self.window.rootViewController;
    while (top.presentedViewController) top = top.presentedViewController;
    return top;
}

@end
