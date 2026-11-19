//
//  DoroSBBall.m
//  SpringBoard 悬浮球：独立高层级 window，跨 App / 回桌面都可见。
//  点击 -> DoroSBWriter 写入 -> 成功倒计时 2 秒 -> 删除文件 + 关球 + 退出工具箱。
//  不再弹任何日志弹窗；结果只用球上的短 toast 提示。
//

#import "DoroSBBall.h"
#import "DoroSBConfig.h"
#import "DoroSBWriter.h"
#import "DoroSBAppExit.h"
#import <UIKit/UIKit.h>

@interface DoroSBBall ()
@property (nonatomic, strong) UIWindow *win;
@property (nonatomic, strong) UIView *ball;
@property (nonatomic, strong) UILabel *toast;
@property (nonatomic, assign) BOOL busy;
@end

@implementation DoroSBBall

+ (instancetype)shared {
    static DoroSBBall *o;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ o = [self new]; });
    return o;
}

// 前台激活的 scene（SpringBoard 同一时刻一般只有一个）
- (UIWindowScene *)activeScene {
    for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
        if ([s isKindOfClass:UIWindowScene.class] &&
            s.activationState == UISceneActivationStateForegroundActive) {
            return (UIWindowScene *)s;
        }
    }
    // 兜底：取第一个 window scene
    for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
        if ([s isKindOfClass:UIWindowScene.class]) return (UIWindowScene *)s;
    }
    return nil;
}

- (void)install {
    if (self.win && !self.win.hidden) return;   // 幂等
    UIWindowScene *scene = [self activeScene];
    if (!scene) {
        // SpringBoard 刚启动可能还没 scene，延迟重试
        __weak typeof(self) wf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{ [wf install]; });
        return;
    }

    UIWindow *w = [[UIWindow alloc] initWithWindowScene:scene];
    w.windowLevel = SB_WINDOW_LEVEL;
    w.backgroundColor = [UIColor clearColor];
    // 透明根 VC：只有球本身吃掉触摸，其余区域穿透
    UIViewController *root = [UIViewController new];
    root.view.backgroundColor = [UIColor clearColor];
    w.rootViewController = root;
    self.win = w;

    const CGFloat d = 68;
    UIView *ball = [[UIView alloc] initWithFrame:CGRectMake(0, 0, d, d)];
    ball.backgroundColor = [UIColor colorWithRed:1 green:0.55 blue:0.78 alpha:0.92];
    ball.layer.cornerRadius = d / 2;
    ball.layer.masksToBounds = YES;
    ball.layer.borderWidth = 2;
    ball.layer.borderColor = [UIColor whiteColor].CGColor;
    // SpringBoard 的 mainBundle 是系统App，头像从 tweak 安装目录读（rootless 优先 /var/jb）
    NSString *avatar = @"/var/jb/Library/Application Support/DoroSB/doro_avatar.jpg";
    if (![[NSFileManager defaultManager] fileExistsAtPath:avatar])
        avatar = @"/Library/Application Support/DoroSB/doro_avatar.jpg";
    UIImage *img = [UIImage imageWithContentsOfFile:avatar];
    UIImageView *iv = [[UIImageView alloc] initWithImage:img];
    iv.frame = ball.bounds;
    iv.contentMode = UIViewContentModeScaleAspectFill;
    iv.clipsToBounds = YES;
    [ball addSubview:iv];
    ball.center = CGPointMake(CGRectGetWidth(w.bounds) - d - 12, CGRectGetHeight(w.bounds) * 0.58);

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(onPan:)];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTap:)];
    [tap requireGestureRecognizerToFail:pan];
    [ball addGestureRecognizer:pan];
    [ball addGestureRecognizer:tap];
    [root.view addSubview:ball];
    self.ball = ball;

    UILabel *toast = [UILabel new];
    toast.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    toast.textColor = [UIColor whiteColor];
    toast.backgroundColor = [UIColor colorWithWhite:0.12 alpha:0.9];
    toast.textAlignment = NSTextAlignmentCenter;
    toast.numberOfLines = 0;
    toast.layer.cornerRadius = 8;
    toast.clipsToBounds = YES;
    toast.alpha = 0;
    [root.view addSubview:toast];
    self.toast = toast;

    w.hidden = NO;   // 不 makeKeyWindow，避免抢走前台 App 的 key 状态
}

- (void)hide {
    self.win.hidden = YES;
    self.win = nil;
    self.ball = nil;
    self.toast = nil;
}

- (void)onPan:(UIPanGestureRecognizer *)pan {
    UIView *ball = pan.view;
    CGPoint t = [pan translationInView:self.win];
    CGPoint c = ball.center;
    c.x += t.x; c.y += t.y;
    CGFloat half = CGRectGetWidth(ball.bounds) / 2;
    c.x = MAX(half + 4, MIN(CGRectGetWidth(self.win.bounds) - half - 4, c.x));
    c.y = MAX(half + 4, MIN(CGRectGetHeight(self.win.bounds) - half - 4, c.y));
    ball.center = c;
    [pan setTranslation:CGPointZero inView:self.win];
}

- (void)onTap:(UITapGestureRecognizer *)tap {
    if (self.busy) return;
    self.busy = YES;
    [self toastText:@"写入中…"];
    __weak typeof(self) wf = self;
    [DoroSBWriter writeWithCompletion:^(BOOL ok, NSString *message, NSString *destPath) {
        __strong typeof(self) strong = wf;
        if (!ok) {
            strong.busy = NO;
            [strong toastText:[NSString stringWithFormat:@"失败：%@", message]];
            return;
        }
        // 成功：显示短提示，2 秒倒计时后删文件 + 关球 + 退出工具箱
        [strong toastText:[NSString stringWithFormat:@"%@\n%.0f 秒后删除并退出", message, SB_AFTER_WRITE_DELAY]];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(SB_AFTER_WRITE_DELAY * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            __strong typeof(self) s = wf;
            if (!s) return;
            if (destPath.length) {
                [[NSFileManager defaultManager] removeItemAtPath:destPath error:nil];
            }
            [s hide];
            [DoroSBAppExit terminateBundle:SB_TOOLBOX_BUNDLE];
        });
    }];
}

- (void)toastText:(NSString *)text {
    UILabel *toast = self.toast;
    UIView *ball = self.ball;
    if (!toast || !ball) return;
    toast.text = text;
    CGSize fit = [toast sizeThatFits:CGSizeMake(260, CGFLOAT_MAX)];
    CGFloat w = MIN(260, fit.width + 24), h = fit.height + 16;
    toast.frame = CGRectMake(CGRectGetMidX(ball.frame) - w / 2,
                             CGRectGetMinY(ball.frame) - h - 8, w, h);
    toast.frame = CGRectMake(MAX(8, MIN(CGRectGetWidth(self.win.bounds) - w - 8, toast.frame.origin.x)),
                             toast.frame.origin.y, w, h);
    [UIView animateWithDuration:0.15 animations:^{ toast.alpha = 1; }
                     completion:^(BOOL finished) {
        __weak typeof(self) wf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [UIView animateWithDuration:0.3 animations:^{ wf.toast.alpha = 0; }];
        });
    }];
}

@end
