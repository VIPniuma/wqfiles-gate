//
//  DoroWriteTest.m
//  WQ Files + 写入测试
//
//  目标：<DeltaForce容器>/Documents/DeltaForce/Saved/
//        LuaDebug/LuaSource/DFM/BusinessEntrance/测试123
//  目录与文件创建全部走 WQAccess 的 wq_create_dir / wq_create_file，
//  它们在沙盒拒绝时自动调用 wq_grant 申请 sandbox extension，即所谓"逃逸漏洞"。
//  容器根路径不写死：优先用确认路径，失败则动态枚举（DeltaForceLocator）。
//  复杂度：O(n)，n = 枚举容器数。
//

#import "DoroWriteTest.h"
#import "DeltaForceLocator.h"
#import "WQAccess.h"
#import <sys/stat.h>

static NSString * const kTargetChain = @"LuaDebug/LuaSource/DFM/BusinessEntrance";
static NSString * const kTestFile    = @"测试123";

@interface DoroWriteTest ()
@property (nonatomic, strong) UIButton *testButton;
@end

@implementation DoroWriteTest

+ (void)installIntoWindow:(UIWindow *)window {
    static DoroWriteTest *installer;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ installer = [[DoroWriteTest alloc] init]; });
    [installer installOnTopOfWindow:window];
}

- (void)installOnTopOfWindow:(UIWindow *)window {
    UIViewController *top = window.rootViewController;
    while (top.presentedViewController) top = top.presentedViewController;
    if (!top.view) return;

    // 用悬浮按钮挂到当前界面，避开 WQRootViewController 对 navigationItem 的占用
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    [btn setTitle:@"测试：创建目录并写入文件" forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    btn.backgroundColor = [UIColor colorWithWhite:0.97 alpha:0.92];
    btn.layer.cornerRadius = 10;
    btn.layer.shadowColor = [UIColor blackColor].CGColor;
    btn.layer.shadowOpacity = 0.18;
    btn.layer.shadowRadius = 4;
    btn.layer.shadowOffset = CGSizeMake(0, 1);
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    [btn addTarget:self action:@selector(onTest:) forControlEvents:UIControlEventTouchUpInside];
    [top.view addSubview:btn];
    self.testButton = btn;
    CGFloat bottom = top.view.safeAreaInsets.bottom + 20;
    [NSLayoutConstraint activateConstraints:@[
        [btn.centerXAnchor constraintEqualToAnchor:top.view.centerXAnchor],
        [btn.bottomAnchor constraintEqualToAnchor:top.view.bottomAnchor constant:-bottom],
    ]];
}

- (void)onTest:(UIButton *)sender {
    sender.enabled = NO;
    __weak typeof(self) wf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *diag = nil;
        NSString *root = [DeltaForceLocator findSavedRoot:&diag];
        NSString *title, *msg;
        if (!root) {
            title = @"未找到 DeltaForce 容器";
            msg = diag ?: @"未知原因";
        } else {
            NSString *target = [root stringByAppendingPathComponent:kTargetChain];
            NSString *err = nil;
            BOOL ok = [wf ensureDirFromRoot:root error:&err];
            if (ok) {
                NSString *file = [target stringByAppendingPathComponent:kTestFile];
                NSData *data = [@"测试123" dataUsingEncoding:NSUTF8StringEncoding];
                BOOL wok = wq_create_file(file, data, &err);
                title = wok ? @"成功" : @"写入文件失败";
                msg = wok
                    ? [NSString stringWithFormat:@"目录：%@\n文件：%@", target, file]
                    : (err ?: @"未知原因");
            } else {
                title = @"创建目录失败";
                msg = err ?: @"未知原因";
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            UIAlertController *ac = [UIAlertController alertControllerWithTitle:title
                                                                       message:msg
                                                                preferredStyle:UIAlertControllerStyleAlert];
            [ac addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
            UIViewController *top = wf.testButton.window.rootViewController;
            while (top.presentedViewController) top = top.presentedViewController;
            [top presentViewController:ac animated:YES completion:nil];
            sender.enabled = YES;
            NSLog(@"[DoroWriteTest] %@ - %@", title, msg);
        });
    });
}

// 逐级创建路径（wq_create_dir 每次只建一级，且会按需 grant token）
- (BOOL)ensureDirFromRoot:(NSString *)root error:(NSString **)err {
    NSArray *parts = [kTargetChain componentsSeparatedByString:@"/"];
    NSString *cur = root;
    struct stat st;
    if (wq_stat(cur, &st) != 0 || !S_ISDIR(st.st_mode)) {
        if (err) *err = @"目标根路径不存在或不是目录";
        return NO;
    }
    for (NSString *part in parts) {
        if (part.length == 0) continue;
        cur = [cur stringByAppendingPathComponent:part];
        if (wq_stat(cur, &st) == 0 && S_ISDIR(st.st_mode)) continue;
        if (!wq_create_dir(cur, err)) return NO;
    }
    return YES;
}

@end
