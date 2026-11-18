//
//  DoroWriteTest.m
//  写入流程复刻自黑猫工具箱：
//   - 安全相对路径校验 WQGameSafeRelative (0x10003884c)
//   - 逐级建链 WQGameEnsureChain (0x10003de80)：wq_stat + wq_create_dir
//   - 写文件 performWrite_block_invoke_2 (0x100044288)：wq_create_file_from 流式写
//   - 写入后 wq_stat 校验
//  目标：<DeltaForce容器>/Documents/
//        DeltaForce/Saved/LuaDebug/LuaSource/DFM/BusinessEntrance/测试123
//  根用容器 Documents，整条链（含 DeltaForce/Saved）由 wq_create_dir 逐级建，
//  这样即使游戏尚未创建 Saved 目录也能写入。复杂度 O(k)，k = 路径级数。
//

#import "DoroWriteTest.h"
#import "DeltaForceLocator.h"
#import "WQAccess.h"
#import <sys/stat.h>

// 完整建链：从 Documents 下开始，Saved 不存在也能逐级新建
static NSString * const kChain = @"DeltaForce/Saved/LuaDebug/LuaSource/DFM/BusinessEntrance";
static NSString * const kFile  = @"测试123";
static NSString * const kBody  = @"测试123";

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
            title = @"未找到三角洲容器";
            msg = diag ?: @"未知原因";
        } else {
            // 黑猫 WQGameSafeRelative：拒绝绝对/含 .. 的相对路径
            if (![wf safeRelative:kChain]) {
                title = @"路径校验失败";
                msg = @"相对路径含非法成分";
            } else {
                NSString *err = nil;
                NSUInteger made = 0;
                BOOL ok = [wf ensureChainFromRoot:root made:&made error:&err];
                if (!ok) {
                    title = @"创建目录失败";
                    msg = err ?: @"未知原因";
                } else {
                    NSString *target = [root stringByAppendingPathComponent:kChain];
                    NSString *file = [target stringByAppendingPathComponent:kFile];
                    BOOL wok = [wf writeFile:file error:&err];
                    title = wok ? @"成功" : @"写入文件失败";
                    if (wok) {
                        struct stat st;
                        BOOL verified = wq_stat(file, &st) == 0 && S_ISREG(st.st_mode) && st.st_size > 0;
                        msg = [NSString stringWithFormat:@"%@目录：%@\n文件：%@\n新建目录：%lu 级\n校验：%@",
                               verified ? @"" : @"警告：写入后校验未通过\n",
                               target, file, (unsigned long)made, verified ? @"通过" : @"未通过"];
                    } else {
                        msg = err ?: @"未知原因";
                    }
                }
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            // worse_query 的完整诊断（App Group / grant token / mkdir / create）附在弹窗，
            // 真机失败时直接看得到是"没拿到 token"还是"路径不对"。
            NSString *log = wq_log_text();
            NSString *full = [NSString stringWithFormat:@"%@\n\n---- worse_query 日志 ----\n%@", msg, log.length > 1200 ? [log substringFromIndex:log.length - 1200] : log];
            UIAlertController *ac = [UIAlertController alertControllerWithTitle:title
                                                                       message:full
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

// 黑猫 WQGameSafeRelative：不以 / 开头、不含 .. 成分
- (BOOL)safeRelative:(NSString *)rel {
    if (rel.length == 0 || [rel hasPrefix:@"/"]) return NO;
    for (NSString *part in [rel componentsSeparatedByString:@"/"]) {
        if ([part isEqualToString:@".."] || [part isEqualToString:@"."]) return NO;
    }
    return YES;
}

// 黑猫 WQGameEnsureChain：逐级 wq_stat，缺失才 wq_create_dir
- (BOOL)ensureChainFromRoot:(NSString *)root made:(NSUInteger *)made error:(NSString **)err {
    struct stat st;
    if (wq_stat(root, &st) != 0 || !S_ISDIR(st.st_mode)) {
        if (err) *err = @"容器根路径不存在或不是目录";
        return NO;
    }
    NSString *cur = root;
    for (NSString *part in [kChain componentsSeparatedByString:@"/"]) {
        if (part.length == 0) continue;
        cur = [cur stringByAppendingPathComponent:part];
        if (wq_stat(cur, &st) == 0 && S_ISDIR(st.st_mode)) continue;
        if (!wq_create_dir(cur, err)) return NO;
        if (made) (*made)++;
    }
    return YES;
}

// 黑猫 performWrite：本地沙盒落临时文件 → wq_create_file_from 流式写 → 校验
- (BOOL)writeFile:(NSString *)dest error:(NSString **)err {
    NSString *tmp = [NSTemporaryDirectory() stringByAppendingPathComponent:
                     [NSString stringWithFormat:@"doro_write_%llu", (unsigned long long)NSDate.date.timeIntervalSince1970]];
    if (![kBody writeToFile:tmp atomically:YES encoding:NSUTF8StringEncoding error:nil]) {
        if (err) *err = @"本地临时文件写入失败";
        return NO;
    }
    BOOL ok = wq_create_file_from(dest, tmp, err);
    [[NSFileManager defaultManager] removeItemAtPath:tmp error:nil];
    return ok;
}

@end
