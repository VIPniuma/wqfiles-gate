//
//  DoroGate.m
//  T3 卡密验证 + 心跳保活。
//  流程：initRsa → 本地卡密静默 login（无则弹 T3VerifyDialog）→ 成功后启动心跳。
//  心跳用 T3 自带 heartbeatWithKami；单次失败即清卡密、推回验证框，并回调 onInvalid 锁功能。
//

#import "DoroGate.h"
#import "DoroHeartbeat.h"
#import "T3Verify.h"
#import "T3VerifyDialog.h"
#import "T3GateConfig.h"

@interface DoroGate ()
@property (nonatomic, strong) T3Verify *verify;
@property (nonatomic, strong) T3VerifyDialog *dialog;
@property (nonatomic, strong) DoroHeartbeat *heartbeat;
@property (nonatomic, weak) UIWindow *window;
@property (nonatomic, copy, nullable) NSString *currentKami;
@property (nonatomic, assign) BOOL verified;
@end

@implementation DoroGate

+ (instancetype)shared {
    static DoroGate *g;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ g = [DoroGate new]; });
    return g;
}

- (instancetype)initWithWindow:(UIWindow *)window {
    if ((self = [super init])) {
        _window = window;
    }
    return self;
}

- (NSString *)kami { return self.currentKami; }
- (NSString *)statecode { return self.verify.statecode; }

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
    self.verified = NO;
    [self.heartbeat stop];
    self.dialog = [[T3VerifyDialog alloc] initWithVerify:self.verify localVersion:T3_LOCAL_VERSION];
    __weak typeof(self) wf = self;
    self.dialog.onLoginSuccess = ^(T3LoginResult *result __unused, NSString *card, NSString *stateCode __unused) {
        [[NSUserDefaults standardUserDefaults] setObject:card forKey:T3_PREF_KEY_CARD];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [wf onVerifiedWithKami:card];
    };
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
                [wf onVerifiedWithKami:card];
            } else {
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:T3_PREF_KEY_CARD];
                [[NSUserDefaults standardUserDefaults] synchronize];
                [wf showGate];
            }
        });
    });
}

- (void)onVerifiedWithKami:(NSString *)card {
    self.currentKami = card;
    UIViewController *top = [self topViewController];
    while (top.presentedViewController) top = top.presentedViewController;
    if (top.presentingViewController) [top dismissViewControllerAnimated:YES completion:nil];
    self.dialog = nil;
    self.verified = YES;
    NSLog(@"[DoroGate] 验证成功，到期=%@", self.verify.endTime ?: @"-");

    // 启动心跳：用 T3 自带 heartbeatWithKami；失败直接推回验证界面
    NSString *sc = self.verify.statecode ?: @"";
    __weak typeof(self) wf = self;
    self.heartbeat = [[DoroHeartbeat alloc] initWithVerify:self.verify
                                                      kami:card
                                                 statecode:sc
                                                  interval:T3_HEARTBEAT_INTERVAL
                                                 onFailure:^(NSString *reason) {
        [wf onHeartbeatFailed:reason];
    }];
    [self.heartbeat start];

    if (self.onSuccess) self.onSuccess();
}

- (void)onHeartbeatFailed:(NSString *)reason {
    NSLog(@"[DoroGate] 心跳失败：%@ —— 清卡密并推回验证界面", reason);
    // 锁功能回调先发（主线程）
    if (self.onInvalid) self.onInvalid(reason);
    // 清本地卡密
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:T3_PREF_KEY_CARD];
    [[NSUserDefaults standardUserDefaults] synchronize];
    self.currentKami = nil;
    self.verified = NO;
    [self showGate];
}

- (UIViewController *)topViewController {
    UIViewController *top = self.window.rootViewController;
    while (top.presentedViewController) top = top.presentedViewController;
    return top;
}

- (void)dealloc {
    [self.heartbeat stop];
}

@end
