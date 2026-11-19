//
//  DoroFloatingBall.m
//  悬浮球：独立 UIWindow（Alert+1 层级，跨页面可见、不抢 key），
//  可拖动、点击触发 DoroScriptInstaller 写入，写入后 10 秒自动删由 installer 调 DoroScriptCleaner。
//  点击结果用轻量 toast（UILabel）提示，不弹 alert 打断操作。
//

#import "DoroFloatingBall.h"
#import "DoroScriptInstaller.h"
#import "DoroGate.h"
#import <UIKit/UIKit.h>

@interface DoroFloatingBall ()
@property (nonatomic, strong) UIWindow *floatWindow;
@property (nonatomic, strong) UIView *ball;
@property (nonatomic, strong) UILabel *toast;
@property (nonatomic, assign) BOOL installing;
@end

@implementation DoroFloatingBall

+ (instancetype)shared {
    static DoroFloatingBall *o = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ o = [[self alloc] init]; });
    return o;
}

- (BOOL)isShowing {
    return self.floatWindow && !self.floatWindow.hidden;
}

// 取前台激活的 UIWindowScene。没有 scene（截图模式/后台）就不显示。
- (UIWindowScene *)activeScene {
    for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
        if ([s isKindOfClass:UIWindowScene.class] &&
            s.activationState == UISceneActivationStateForegroundActive) {
            return (UIWindowScene *)s;
        }
    }
    return nil;
}

- (void)show {
    if ([self isShowing]) return;
    UIWindowScene *scene = [self activeScene];
    if (!scene) return;

    UIWindow *w = [[UIWindow alloc] initWithWindowScene:scene];
    w.windowLevel = UIWindowLevelAlert + 1;   // 高于普通界面，低于系统弹窗
    w.backgroundColor = [UIColor clearColor];
    w.frame = scene.screen.bounds;

    // 透明根 VC：只让球本身可点击，其余区域事件穿透到下层界面
    UIViewController *root = [UIViewController new];
    root.view.backgroundColor = [UIColor clearColor];
    w.rootViewController = root;
    self.floatWindow = w;

    // 悬浮球本体：Doro 头像，74pt 圆形
    const CGFloat d = 74;
    UIView *ball = [[UIView alloc] initWithFrame:CGRectMake(0, 0, d, d)];
    ball.backgroundColor = [UIColor colorWithRed:1 green:0.72 blue:0.86 alpha:0.95];
    ball.layer.cornerRadius = d / 2;
    ball.layer.masksToBounds = YES;
    ball.layer.borderWidth = 2;
    ball.layer.borderColor = [UIColor whiteColor].CGColor;
    UIImage *img = [UIImage imageWithContentsOfFile:[NSBundle.mainBundle pathForResource:@"doro_avatar" ofType:@"jpg"]];
    UIImageView *iv = [[UIImageView alloc] initWithImage:img];
    iv.frame = ball.bounds;
    iv.contentMode = UIViewContentModeScaleAspectFill;
    iv.clipsToBounds = YES;
    [ball addSubview:iv];

    // 初始位置：右下角、避开底部安全区
    CGFloat x = CGRectGetWidth(w.bounds) - d - 16;
    CGFloat y = CGRectGetHeight(w.bounds) - d - 90;
    ball.center = CGPointMake(x, y);

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(onPan:)];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTap:)];
    tap.numberOfTapsRequired = 1;
    [tap requireGestureRecognizerToFail:pan];   // 拖动不算点击
    [ball addGestureRecognizer:pan];
    [ball addGestureRecognizer:tap];
    [root.view addSubview:ball];
    self.ball = ball;

    // toast：球上方的小提示条，默认隐藏
    UILabel *toast = [UILabel new];
    toast.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    toast.textColor = [UIColor whiteColor];
    toast.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.85];
    toast.textAlignment = NSTextAlignmentCenter;
    toast.numberOfLines = 2;
    toast.layer.cornerRadius = 8;
    toast.clipsToBounds = YES;
    toast.alpha = 0;
    [root.view addSubview:toast];
    self.toast = toast;

    w.hidden = NO;   // 不用 makeKeyAndVisible，避免抢走主界面 key 状态
}

- (void)hide {
    self.floatWindow.hidden = YES;
    self.floatWindow = nil;
    self.ball = nil;
    self.toast = nil;
}

- (void)onPan:(UIPanGestureRecognizer *)pan {
    UIView *ball = pan.view;
    CGPoint t = [pan translationInView:self.floatWindow];
    CGPoint c = ball.center;
    c.x += t.x; c.y += t.y;
    // 限制在屏幕内
    CGFloat half = CGRectGetWidth(ball.bounds) / 2;
    c.x = MAX(half + 4, MIN(CGRectGetWidth(self.floatWindow.bounds) - half - 4, c.x));
    c.y = MAX(half + 4, MIN(CGRectGetHeight(self.floatWindow.bounds) - half - 4, c.y));
    ball.center = c;
    [pan setTranslation:CGPointZero inView:self.floatWindow];
}

- (void)onTap:(UITapGestureRecognizer *)tap {
    if (self.installing) return;
    DoroGate *gate = [DoroGate shared];
    NSString *kami = gate.kami ?: @"";
    NSString *sc = gate.statecode ?: @"";
    if (!kami.length) {
        [self toastText:@"未验证，请先完成卡密验证"];
        return;
    }
    self.installing = YES;
    [self toastText:@"写入中…"];
    __weak typeof(self) wf = self;
    [DoroScriptInstaller installWithKami:kami statecode:sc completion:^(BOOL ok, NSString *message) {
        wf.installing = NO;
        NSString *brief = ok ? @"已写入，10 秒后自动删除" : [NSString stringWithFormat:@"写入失败：%@", message];
        [wf toastText:brief];
    }];
}

- (void)toastText:(NSString *)text {
    UILabel *toast = self.toast;
    UIView *ball = self.ball;
    if (!toast || !ball) return;
    toast.text = text;
    [toast sizeToFit];
    CGRect b = toast.bounds;
    toast.frame = CGRectMake(CGRectGetMidX(ball.frame) - CGRectGetWidth(b) / 2 - 12,
                             CGRectGetMinY(ball.frame) - CGRectGetHeight(b) - 10,
                             CGRectGetWidth(b) + 24, CGRectGetHeight(b) + 12);
    // 不超出屏幕左右
    toast.frame = CGRectMake(MAX(8, MIN(CGRectGetWidth(self.floatWindow.bounds) - CGRectGetWidth(toast.frame) - 8, toast.frame.origin.x)),
                             toast.frame.origin.y, toast.frame.size.width, toast.frame.size.height);
    [UIView animateWithDuration:0.15 animations:^{ toast.alpha = 1; }
                     completion:^(BOOL finished) {
                         dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                             [UIView animateWithDuration:0.3 animations:^{ toast.alpha = 0; }];
                         });
                     }];
}

@end
