/**
 * 网络验证 iOS 弹窗验证组件
 * 官网: https://www.t3yanzheng.com
 */

#import "T3VerifyDialog.h"
#import "T3GateConfig.h"

// ============================================================
// 主题色定义
// ============================================================

#define T3_COLOR_PRIMARY     [UIColor colorWithRed:0.42 green:0.39 blue:1.0 alpha:1.0]        // #6C63FF
#define T3_COLOR_PRIMARY_DK  [UIColor colorWithRed:0.35 green:0.32 blue:0.88 alpha:1.0]       // #5A52E0
#define T3_COLOR_BG          [UIColor colorWithRed:0.94 green:0.95 blue:0.96 alpha:1.0]        // #F0F2F5
#define T3_COLOR_CARD        [UIColor whiteColor]
#define T3_COLOR_TEXT_PRI    [UIColor colorWithRed:0.10 green:0.10 blue:0.18 alpha:1.0]        // #1A1A2E
#define T3_COLOR_TEXT_SEC    [UIColor colorWithRed:0.42 green:0.44 blue:0.50 alpha:1.0]        // #6B7280
#define T3_COLOR_TEXT_HINT   [UIColor colorWithRed:0.61 green:0.64 blue:0.69 alpha:1.0]        // #9CA3AF
#define T3_COLOR_SUCCESS     [UIColor colorWithRed:0.06 green:0.73 blue:0.51 alpha:1.0]        // #10B981
#define T3_COLOR_WARNING     [UIColor colorWithRed:0.96 green:0.62 blue:0.04 alpha:1.0]        // #F59E0B
#define T3_COLOR_ERROR       [UIColor colorWithRed:0.94 green:0.27 blue:0.27 alpha:1.0]        // #EF4444
#define T3_COLOR_DIVIDER     [UIColor colorWithRed:0.90 green:0.91 blue:0.92 alpha:1.0]        // #E5E7EB
#define T3_COLOR_INPUT_BG    [UIColor colorWithRed:0.98 green:0.98 blue:0.98 alpha:1.0]        // #F9FAFB
#define T3_COLOR_INPUT_BDR   [UIColor colorWithRed:0.82 green:0.84 blue:0.86 alpha:1.0]        // #D1D5DB


@interface T3VerifyDialog () <UITextFieldDelegate>
@property (nonatomic, strong) T3Verify *verify;
@property (nonatomic, copy) NSString *localVersion;
@property (nonatomic, strong) UIViewController *presentingVC;
@property (nonatomic, strong) UIViewController *dialogVC;
// UI 元素
@property (nonatomic, strong) UILabel *noticeContent;
@property (nonatomic, strong) UILabel *versionContent;
@property (nonatomic, strong) UILabel *versionBadge;
@property (nonatomic, strong) UITextField *kamiInput;
@property (nonatomic, strong) UIButton *loginButton;
@property (nonatomic, strong) UILabel *statusLabel;
@end


@implementation T3VerifyDialog

- (instancetype)initWithVerify:(T3Verify *)verify localVersion:(NSString *)localVersion {
    self = [super init];
    if (self) {
        _verify = verify;
        _localVersion = localVersion;
    }
    return self;
}

// ============================================================
// 展示弹窗
// ============================================================

- (void)showInViewController:(UIViewController *)viewController {
    self.presentingVC = viewController;

    UIViewController *vc = [[UIViewController alloc] init];
    vc.modalPresentationStyle = UIModalPresentationOverFullScreen;
    vc.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    self.dialogVC = vc;

    UIView *root = vc.view;
    root.backgroundColor = T3_COLOR_BG;

    // ---- ScrollView ----
    UIScrollView *scroll = [[UIScrollView alloc] init];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.showsVerticalScrollIndicator = NO;
    [root addSubview:scroll];

    UIView *contentView = [[UIView alloc] init];
    contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:contentView];

    // ScrollView 约束
    [NSLayoutConstraint activateConstraints:@[
        [scroll.topAnchor constraintEqualToAnchor:root.safeAreaLayoutGuide.topAnchor],
        [scroll.leadingAnchor constraintEqualToAnchor:root.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:root.trailingAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:root.bottomAnchor],
        [contentView.topAnchor constraintEqualToAnchor:scroll.topAnchor],
        [contentView.leadingAnchor constraintEqualToAnchor:scroll.leadingAnchor],
        [contentView.trailingAnchor constraintEqualToAnchor:scroll.trailingAnchor],
        [contentView.bottomAnchor constraintEqualToAnchor:scroll.bottomAnchor],
        [contentView.widthAnchor constraintEqualToAnchor:scroll.widthAnchor]
    ]];

    CGFloat pad = 20;
    CGFloat top = 24;

    // ---- LOGO（图片优先，找不到则回退文字） ----
    UIView *logo;
    UIImage *logoImg = [UIImage imageNamed:@"doro_logo"];
    if (logoImg) {
        UIImageView *logoIV = [[UIImageView alloc] initWithImage:logoImg];
        logoIV.contentMode = UIViewContentModeScaleAspectFit;
        logoIV.layer.cornerRadius = 26;
        logoIV.clipsToBounds = YES;
        logo = logoIV;
    } else {
        UILabel *logoLb = [[UILabel alloc] init];
        logoLb.text = T3_GATE_LOGO;
        logoLb.font = [UIFont boldSystemFontOfSize:22];
        logoLb.textColor = [UIColor whiteColor];
        logoLb.textAlignment = NSTextAlignmentCenter;
        logoLb.backgroundColor = T3_COLOR_PRIMARY;
        logoLb.layer.cornerRadius = 26;
        logoLb.clipsToBounds = YES;
        logo = logoLb;
    }
    logo.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:logo];

    [NSLayoutConstraint activateConstraints:@[
        [logo.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:top],
        [logo.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
        [logo.widthAnchor constraintEqualToConstant:64],
        [logo.heightAnchor constraintEqualToConstant:64]
    ]];

    // ---- 标题 ----
    UILabel *title = [self labelWithText:T3_GATE_TITLE
                                    font:[UIFont boldSystemFontOfSize:20]
                                   color:T3_COLOR_TEXT_PRI];
    title.textAlignment = NSTextAlignmentCenter;
    [contentView addSubview:title];
    [NSLayoutConstraint activateConstraints:@[
        [title.topAnchor constraintEqualToAnchor:logo.bottomAnchor constant:10],
        [title.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:pad],
        [title.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-pad]
    ]];

    // ---- 副标题 ----
    UILabel *subtitle = [self labelWithText:T3_GATE_SUBTITLE
                                       font:[UIFont systemFontOfSize:13]
                                      color:T3_COLOR_TEXT_SEC];
    subtitle.textAlignment = NSTextAlignmentCenter;
    [contentView addSubview:subtitle];
    [NSLayoutConstraint activateConstraints:@[
        [subtitle.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:2],
        [subtitle.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:pad],
        [subtitle.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-pad]
    ]];

    // ---- 公告卡片 ----
    UIView *noticeCard = [self createCard];
    [contentView addSubview:noticeCard];
    [NSLayoutConstraint activateConstraints:@[
        [noticeCard.topAnchor constraintEqualToAnchor:subtitle.bottomAnchor constant:20],
        [noticeCard.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:pad],
        [noticeCard.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-pad]
    ]];

    // 公告标题行
    UIView *noticeTitleRow = [self createTitleRowWithDotColor:T3_COLOR_WARNING text:@"公告"];
    [noticeCard addSubview:noticeTitleRow];
    [NSLayoutConstraint activateConstraints:@[
        [noticeTitleRow.topAnchor constraintEqualToAnchor:noticeCard.topAnchor constant:14],
        [noticeTitleRow.leadingAnchor constraintEqualToAnchor:noticeCard.leadingAnchor constant:16],
        [noticeTitleRow.trailingAnchor constraintEqualToAnchor:noticeCard.trailingAnchor constant:-16]
    ]];

    self.noticeContent = [self labelWithText:@"正在加载..."
                                        font:[UIFont systemFontOfSize:13]
                                       color:T3_COLOR_TEXT_SEC];
    self.noticeContent.numberOfLines = 5;
    [noticeCard addSubview:self.noticeContent];
    [NSLayoutConstraint activateConstraints:@[
        [self.noticeContent.topAnchor constraintEqualToAnchor:noticeTitleRow.bottomAnchor constant:8],
        [self.noticeContent.leadingAnchor constraintEqualToAnchor:noticeCard.leadingAnchor constant:16],
        [self.noticeContent.trailingAnchor constraintEqualToAnchor:noticeCard.trailingAnchor constant:-16],
        [self.noticeContent.bottomAnchor constraintEqualToAnchor:noticeCard.bottomAnchor constant:-14]
    ]];

    // ---- 版本卡片 ----
    UIView *versionCard = [self createCard];
    [contentView addSubview:versionCard];
    [NSLayoutConstraint activateConstraints:@[
        [versionCard.topAnchor constraintEqualToAnchor:noticeCard.bottomAnchor constant:10],
        [versionCard.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:pad],
        [versionCard.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-pad]
    ]];

    UIView *verTitleRow = [self createTitleRowWithDotColor:T3_COLOR_PRIMARY text:@"版本信息"];
    [versionCard addSubview:verTitleRow];
    [NSLayoutConstraint activateConstraints:@[
        [verTitleRow.topAnchor constraintEqualToAnchor:versionCard.topAnchor constant:14],
        [verTitleRow.leadingAnchor constraintEqualToAnchor:versionCard.leadingAnchor constant:16],
        [verTitleRow.trailingAnchor constraintEqualToAnchor:versionCard.trailingAnchor constant:-16]
    ]];

    self.versionContent = [self labelWithText:@"正在加载..."
                                         font:[UIFont systemFontOfSize:13]
                                        color:T3_COLOR_TEXT_SEC];
    [versionCard addSubview:self.versionContent];
    [NSLayoutConstraint activateConstraints:@[
        [self.versionContent.topAnchor constraintEqualToAnchor:verTitleRow.bottomAnchor constant:8],
        [self.versionContent.leadingAnchor constraintEqualToAnchor:versionCard.leadingAnchor constant:16],
        [self.versionContent.trailingAnchor constraintEqualToAnchor:versionCard.trailingAnchor constant:-16]
    ]];

    // 版本状态 Badge
    self.versionBadge = [[UILabel alloc] init];
    self.versionBadge.font = [UIFont boldSystemFontOfSize:11];
    self.versionBadge.textColor = [UIColor whiteColor];
    self.versionBadge.textAlignment = NSTextAlignmentCenter;
    self.versionBadge.layer.cornerRadius = 10;
    self.versionBadge.clipsToBounds = YES;
    self.versionBadge.hidden = YES;
    self.versionBadge.translatesAutoresizingMaskIntoConstraints = NO;
    [versionCard addSubview:self.versionBadge];
    [NSLayoutConstraint activateConstraints:@[
        [self.versionBadge.topAnchor constraintEqualToAnchor:self.versionContent.bottomAnchor constant:8],
        [self.versionBadge.leadingAnchor constraintEqualToAnchor:versionCard.leadingAnchor constant:16],
        [self.versionBadge.heightAnchor constraintEqualToConstant:22],
        [self.versionBadge.bottomAnchor constraintEqualToAnchor:versionCard.bottomAnchor constant:-14]
    ]];

    // Badge 内边距通过宽度约束实现
    NSLayoutConstraint *badgeWidth = [self.versionBadge.widthAnchor constraintGreaterThanOrEqualToConstant:80];
    badgeWidth.active = YES;

    // ---- 登录卡片 ----
    UIView *loginCard = [self createCard];
    [contentView addSubview:loginCard];
    [NSLayoutConstraint activateConstraints:@[
        [loginCard.topAnchor constraintEqualToAnchor:versionCard.bottomAnchor constant:18],
        [loginCard.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:pad],
        [loginCard.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-pad]
    ]];

    UILabel *loginTitle = [self labelWithText:@"卡密验证"
                                         font:[UIFont boldSystemFontOfSize:14]
                                        color:T3_COLOR_TEXT_PRI];
    [loginCard addSubview:loginTitle];
    [NSLayoutConstraint activateConstraints:@[
        [loginTitle.topAnchor constraintEqualToAnchor:loginCard.topAnchor constant:14],
        [loginTitle.leadingAnchor constraintEqualToAnchor:loginCard.leadingAnchor constant:16],
        [loginTitle.trailingAnchor constraintEqualToAnchor:loginCard.trailingAnchor constant:-16]
    ]];

    // 卡密输入框
    self.kamiInput = [[UITextField alloc] init];
    self.kamiInput.placeholder = @"请输入卡密";
    self.kamiInput.font = [UIFont systemFontOfSize:14];
    self.kamiInput.textColor = T3_COLOR_TEXT_PRI;
    self.kamiInput.backgroundColor = T3_COLOR_INPUT_BG;
    self.kamiInput.layer.cornerRadius = 10;
    self.kamiInput.layer.borderWidth = 1;
    self.kamiInput.layer.borderColor = T3_COLOR_INPUT_BDR.CGColor;
    self.kamiInput.autocorrectionType = UITextAutocorrectionTypeNo;
    self.kamiInput.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.kamiInput.returnKeyType = UIReturnKeyDone;
    self.kamiInput.delegate = self;
    // 内边距
    self.kamiInput.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 14, 0)];
    self.kamiInput.leftViewMode = UITextFieldViewModeAlways;
    self.kamiInput.rightView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 14, 0)];
    self.kamiInput.rightViewMode = UITextFieldViewModeAlways;
    self.kamiInput.translatesAutoresizingMaskIntoConstraints = NO;
    [loginCard addSubview:self.kamiInput];
    [NSLayoutConstraint activateConstraints:@[
        [self.kamiInput.topAnchor constraintEqualToAnchor:loginTitle.bottomAnchor constant:12],
        [self.kamiInput.leadingAnchor constraintEqualToAnchor:loginCard.leadingAnchor constant:16],
        [self.kamiInput.trailingAnchor constraintEqualToAnchor:loginCard.trailingAnchor constant:-16],
        [self.kamiInput.heightAnchor constraintEqualToConstant:46]
    ]];

    // 登录按钮
    self.loginButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.loginButton setTitle:@"登  录" forState:UIControlStateNormal];
    self.loginButton.titleLabel.font = [UIFont boldSystemFontOfSize:15];
    [self.loginButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.loginButton.backgroundColor = T3_COLOR_PRIMARY;
    self.loginButton.layer.cornerRadius = 10;
    [self.loginButton addTarget:self action:@selector(onLoginTapped) forControlEvents:UIControlEventTouchUpInside];
    self.loginButton.translatesAutoresizingMaskIntoConstraints = NO;
    [loginCard addSubview:self.loginButton];
    [NSLayoutConstraint activateConstraints:@[
        [self.loginButton.topAnchor constraintEqualToAnchor:self.kamiInput.bottomAnchor constant:14],
        [self.loginButton.leadingAnchor constraintEqualToAnchor:loginCard.leadingAnchor constant:16],
        [self.loginButton.trailingAnchor constraintEqualToAnchor:loginCard.trailingAnchor constant:-16],
        [self.loginButton.heightAnchor constraintEqualToConstant:46]
    ]];

    // 状态提示
    self.statusLabel = [self labelWithText:@""
                                      font:[UIFont systemFontOfSize:12]
                                     color:T3_COLOR_TEXT_SEC];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.hidden = YES;
    [loginCard addSubview:self.statusLabel];
    [NSLayoutConstraint activateConstraints:@[
        [self.statusLabel.topAnchor constraintEqualToAnchor:self.loginButton.bottomAnchor constant:10],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:loginCard.leadingAnchor constant:16],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:loginCard.trailingAnchor constant:-16],
        [self.statusLabel.bottomAnchor constraintEqualToAnchor:loginCard.bottomAnchor constant:-14]
    ]];

    // ---- 底部版权 ----
    UILabel *copyright = [self labelWithText:T3_GATE_FOOTER
                                        font:[UIFont systemFontOfSize:11]
                                       color:T3_COLOR_TEXT_HINT];
    copyright.textAlignment = NSTextAlignmentCenter;
    [contentView addSubview:copyright];
    [NSLayoutConstraint activateConstraints:@[
        [copyright.topAnchor constraintEqualToAnchor:loginCard.bottomAnchor constant:16],
        [copyright.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:pad],
        [copyright.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-pad],
        [copyright.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-24]
    ]];

    // 展示弹窗
    [viewController presentViewController:vc animated:YES completion:^{
        [self loadData];
    }];
}

// ============================================================
// 加载数据（后台线程）
// ============================================================

- (void)loadData {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // 获取公告
        T3NoticeResult *noticeResult = [self.verify getNotice];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (noticeResult.success) {
                self.noticeContent.text = noticeResult.notice;
            } else {
                self.noticeContent.text = [NSString stringWithFormat:@"获取失败: %@", noticeResult.error];
                self.noticeContent.textColor = T3_COLOR_ERROR;
            }
        });

        // 获取版本号
        T3VersionResult *versionResult = [self.verify getLatestVersion];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (versionResult.success) {
                NSString *remoteVer = versionResult.version;
                self.versionContent.text = [NSString stringWithFormat:@"本地版本  %@   |   最新版本  %@",
                                            self.localVersion, remoteVer];

                self.versionBadge.hidden = NO;
                if (remoteVer && [remoteVer compare:self.localVersion options:NSNumericSearch] == NSOrderedDescending) {
                    self.versionBadge.text = @"  有新版本可用  ";
                    self.versionBadge.backgroundColor = T3_COLOR_WARNING;
                } else {
                    self.versionBadge.text = @"  已是最新版本  ";
                    self.versionBadge.backgroundColor = T3_COLOR_SUCCESS;
                }
            } else {
                self.versionContent.text = [NSString stringWithFormat:@"获取失败: %@", versionResult.error];
                self.versionContent.textColor = T3_COLOR_ERROR;
            }
        });
    });
}

// ============================================================
// 登录事件
// ============================================================

- (void)onLoginTapped {
    NSString *kami = [self.kamiInput.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (kami.length == 0) {
        [self showToast:@"请输入卡密"];
        return;
    }

    [self.kamiInput resignFirstResponder];
    self.loginButton.enabled = NO;
    [self.loginButton setTitle:@"验证中..." forState:UIControlStateNormal];
    self.loginButton.backgroundColor = T3_COLOR_PRIMARY_DK;
    self.statusLabel.hidden = NO;
    self.statusLabel.text = @"正在连接服务器...";
    self.statusLabel.textColor = T3_COLOR_PRIMARY;

    NSString *machineCode = [T3Verify getMachineCode];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        T3LoginResult *result = [self.verify loginWithKami:kami imei:machineCode];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (result.success) {
                // 登录成功，关闭弹窗
                [self.dialogVC dismissViewControllerAnimated:YES completion:^{
                    if (self.onLoginSuccess) {
                        self.onLoginSuccess(result, kami, result.statecode);
                    }
                }];
            } else {
                // 登录失败
                self.loginButton.enabled = YES;
                [self.loginButton setTitle:@"登  录" forState:UIControlStateNormal];
                self.loginButton.backgroundColor = T3_COLOR_PRIMARY;
                self.statusLabel.hidden = NO;
                self.statusLabel.text = result.error;
                self.statusLabel.textColor = T3_COLOR_ERROR;
            }
        });
    });
}

// ============================================================
// UITextField Delegate
// ============================================================

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self onLoginTapped];
    return YES;
}

// ============================================================
// UI 工具方法
// ============================================================

- (UIView *)createCard {
    UIView *card = [[UIView alloc] init];
    card.backgroundColor = T3_COLOR_CARD;
    card.layer.cornerRadius = 12;
    card.layer.shadowColor = [UIColor colorWithWhite:0 alpha:0.06].CGColor;
    card.layer.shadowOffset = CGSizeMake(0, 2);
    card.layer.shadowRadius = 8;
    card.layer.shadowOpacity = 1.0;
    card.translatesAutoresizingMaskIntoConstraints = NO;
    return card;
}

- (UIView *)createTitleRowWithDotColor:(UIColor *)dotColor text:(NSString *)text {
    UIView *row = [[UIView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;

    UIView *dot = [[UIView alloc] init];
    dot.backgroundColor = dotColor;
    dot.layer.cornerRadius = 4;
    dot.translatesAutoresizingMaskIntoConstraints = NO;
    [row addSubview:dot];

    UILabel *label = [self labelWithText:text
                                    font:[UIFont boldSystemFontOfSize:14]
                                   color:T3_COLOR_TEXT_PRI];
    [row addSubview:label];

    [NSLayoutConstraint activateConstraints:@[
        [dot.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [dot.centerYAnchor constraintEqualToAnchor:label.centerYAnchor],
        [dot.widthAnchor constraintEqualToConstant:8],
        [dot.heightAnchor constraintEqualToConstant:8],
        [label.leadingAnchor constraintEqualToAnchor:dot.trailingAnchor constant:8],
        [label.topAnchor constraintEqualToAnchor:row.topAnchor],
        [label.bottomAnchor constraintEqualToAnchor:row.bottomAnchor],
        [label.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
        [row.heightAnchor constraintEqualToConstant:20]
    ]];
    return row;
}

- (UILabel *)labelWithText:(NSString *)text font:(UIFont *)font color:(UIColor *)color {
    UILabel *label = [[UILabel alloc] init];
    label.text = text;
    label.font = font;
    label.textColor = color;
    label.numberOfLines = 0;
    label.translatesAutoresizingMaskIntoConstraints = NO;
    return label;
}

- (void)showToast:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil
                                                                  message:message
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [self.dialogVC presentViewController:alert animated:YES completion:nil];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [alert dismissViewControllerAnimated:YES completion:nil];
    });
}

@end
