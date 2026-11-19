//
//  DoroHomeViewController.m
//  极简首页：顶部「Doro工具箱」+ Doro 头像，中间 16:9 T3 公告栏，
//  下方两个大圆形按钮：绿色「启动」（生成测试文件）、红色「删除」。
//  只管布局与公告/结果弹窗，文件读写交给 DoroWriteTest / DoroDeleteTest。
//

#import "DoroHomeViewController.h"
#import "DoroWriteTest.h"
#import "DoroDeleteTest.h"
#import "WQAccess.h"
#import "T3Verify.h"
#import "T3GateConfig.h"

@implementation DoroHomeViewController {
    UILabel *_noticeLabel;
    UIButton *_startBtn;
    UIButton *_deleteBtn;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];

    // ---- 顶部：左标题、右头像（等高） ----
    UILabel *brand = [UILabel new];
    brand.text = @"Doro工具箱";
    brand.font = [UIFont systemFontOfSize:24 weight:UIFontWeightBold];
    [brand setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

    UIImage *avatarImg = [UIImage imageWithContentsOfFile:[NSBundle.mainBundle pathForResource:@"doro_avatar" ofType:@"jpg"]];
    UIImageView *avatar = [[UIImageView alloc] initWithImage:avatarImg];
    avatar.contentMode = UIViewContentModeScaleAspectFill;
    avatar.clipsToBounds = YES;
    avatar.layer.cornerRadius = 8;
    if (!avatarImg) avatar.backgroundColor = [UIColor colorWithRed:1 green:0.7 blue:0.85 alpha:1];
    [NSLayoutConstraint activateConstraints:@[
        [avatar.widthAnchor constraintEqualToConstant:34],
        [avatar.heightAnchor constraintEqualToConstant:34],
    ]];

    UIStackView *header = [[UIStackView alloc] initWithArrangedSubviews:@[brand, avatar]];
    header.axis = UILayoutConstraintAxisHorizontal;
    header.alignment = UIStackViewAlignmentCenter;
    header.distribution = UIStackViewDistributionEqualSpacing;

    // ---- 公告标题：居中「公告」二字 ----
    UILabel *noticeTitle = [UILabel new];
    noticeTitle.text = @"公告";
    noticeTitle.font = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];
    noticeTitle.textAlignment = NSTextAlignmentCenter;
    noticeTitle.translatesAutoresizingMaskIntoConstraints = NO;

    // ---- 公告栏：16:9 圆角卡片 ----
    UIView *noticeCard = [UIView new];
    noticeCard.backgroundColor = [UIColor colorWithRed:0.97 green:0.95 blue:0.98 alpha:1];
    noticeCard.layer.cornerRadius = 12;
    noticeCard.layer.borderWidth = 1;
    noticeCard.layer.borderColor = [UIColor colorWithWhite:0.9 alpha:1].CGColor;
    _noticeLabel = [UILabel new];
    _noticeLabel.text = @"公告加载中…";
    _noticeLabel.font = [UIFont systemFontOfSize:14];
    _noticeLabel.textColor = [UIColor darkGrayColor];
    _noticeLabel.numberOfLines = 0;
    _noticeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [noticeCard addSubview:_noticeLabel];
    [NSLayoutConstraint activateConstraints:@[
        [_noticeLabel.topAnchor constraintEqualToAnchor:noticeCard.topAnchor constant:10],
        [_noticeLabel.bottomAnchor constraintEqualToAnchor:noticeCard.bottomAnchor constant:-10],
        [_noticeLabel.leadingAnchor constraintEqualToAnchor:noticeCard.leadingAnchor constant:12],
        [_noticeLabel.trailingAnchor constraintEqualToAnchor:noticeCard.trailingAnchor constant:-12],
    ]];
    [self loadNotice];

    // ---- 两个大圆形按钮，上下排列 ----
    _startBtn = [self makeCircleButtonWithTitle:@"启动" color:[UIColor colorWithRed:0.18 green:0.72 blue:0.35 alpha:1]];
    [_startBtn addTarget:self action:@selector(onStart:) forControlEvents:UIControlEventTouchUpInside];
    _deleteBtn = [self makeCircleButtonWithTitle:@"删除" color:[UIColor colorWithRed:0.9 green:0.23 blue:0.2 alpha:1]];
    [_deleteBtn addTarget:self action:@selector(onDelete:) forControlEvents:UIControlEventTouchUpInside];

    UIStackView *content = [[UIStackView alloc] initWithArrangedSubviews:@[noticeTitle, noticeCard, _startBtn, _deleteBtn]];
    content.axis = UILayoutConstraintAxisVertical;
    content.alignment = UIStackViewAlignmentCenter;
    content.spacing = 28;
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:header];
    [self.view addSubview:content];
    header.translatesAutoresizingMaskIntoConstraints = NO;

    UILayoutGuide *g = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [header.topAnchor constraintEqualToAnchor:g.topAnchor constant:16],
        [header.leadingAnchor constraintEqualToAnchor:g.leadingAnchor constant:20],
        [header.trailingAnchor constraintEqualToAnchor:g.trailingAnchor constant:-20],
        [content.topAnchor constraintEqualToAnchor:header.bottomAnchor constant:24],
        [content.leadingAnchor constraintEqualToAnchor:g.leadingAnchor constant:20],
        [content.trailingAnchor constraintEqualToAnchor:g.trailingAnchor constant:-20],
        [noticeTitle.widthAnchor constraintEqualToAnchor:content.widthAnchor],
        [noticeCard.widthAnchor constraintEqualToAnchor:content.widthAnchor],
        [noticeCard.heightAnchor constraintEqualToAnchor:noticeCard.widthAnchor multiplier:9.0/16.0],  // 16:9
    ]];
}

- (UIButton *)makeCircleButtonWithTitle:(NSString *)title color:(UIColor *)color {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    [btn setTitle:title forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont systemFontOfSize:22 weight:UIFontWeightBold];
    btn.backgroundColor = color;
    btn.layer.cornerRadius = 60;   // 直径 120 的大圆
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [btn.widthAnchor constraintEqualToConstant:120],
        [btn.heightAnchor constraintEqualToConstant:120],
    ]];
    return btn;
}

// T3 SDK 公告：getNotice 不依赖登录态，首页自建一个 verify 拉取即可。
- (void)loadNotice {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        T3Verify *verify = [[T3Verify alloc] init];
        NSError *err = nil;
        [verify initRsaWithLoginCode:T3_LOGIN_CODE
                          noticeCode:T3_NOTICE_CODE
                         versionCode:T3_VERSION_CODE
                        heartbeatCode:T3_HEARTBEAT_CODE
                             appkey:T3_APPKEY
                       rsaPublicKey:T3_RSA_PUBLIC_KEY
                              error:&err];
        NSString *text = nil;
        if (!err) {
            T3NoticeResult *r = [verify getNotice];
            text = r.notice;
        }
        __weak typeof(self) wf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(self) strongSelf = wf;
            if (strongSelf) strongSelf->_noticeLabel.text = text.length ? text : @"暂无公告";
        });
    });
}

- (void)onStart:(UIButton *)sender {
    sender.enabled = NO;
    __weak typeof(self) wf = self;
    [DoroWriteTest runWithHost:self completion:^(NSString *title, NSString *message) {
        sender.enabled = YES;
        [wf showTitle:title message:message];
    }];
}

- (void)onDelete:(UIButton *)sender {
    sender.enabled = NO;
    __weak typeof(self) wf = self;
    [DoroDeleteTest runWithHost:self completion:^(NSString *title, NSString *message) {
        sender.enabled = YES;
        [wf showTitle:title message:message];
    }];
}

- (void)showTitle:(NSString *)title message:(NSString *)message {
    NSString *log = wq_log_text();
    NSString *full = log.length
        ? [NSString stringWithFormat:@"%@\n\n---- worse_query 日志 ----\n%@", message,
           log.length > 1000 ? [log substringFromIndex:log.length - 1000] : log]
        : message;
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:title
                                                                message:full
                                                         preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:ac animated:YES completion:nil];
}

@end
