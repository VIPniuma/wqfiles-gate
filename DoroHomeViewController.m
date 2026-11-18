//
//  DoroHomeViewController.m
//  极简首页 UI：标题 + 两个并排按钮。按钮行为分别委托给
//  DoroWriteTest（生成）与 DoroDeleteTest（删除）两个独立模块，
//  本文件只管布局与结果弹窗，不含任何文件读写逻辑。
//

#import "DoroHomeViewController.h"
#import "DoroWriteTest.h"
#import "DoroDeleteTest.h"
#import "WQAccess.h"

@implementation DoroHomeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackground;
    self.title = @"首页";
    self.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"首页"
                                                   image:[UIImage systemImageNamed:@"house"]
                                           selectedImage:[UIImage systemImageNamed:@"house.fill"]];

    UILabel *title = [UILabel new];
    title.text = @"三角洲测试";
    title.font = [UIFont preferredFontForTextStyle:UIFontTextStyleTitle1];
    title.textAlignment = NSTextAlignmentCenter;

    UILabel *hint = [UILabel new];
    hint.text = @"生成 / 删除Documents里的测试文件";
    hint.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    hint.textColor = UIColor.secondaryLabelColor;
    hint.textAlignment = NSTextAlignmentCenter;
    hint.numberOfLines = 0;

    UIButton *generate = [self makeButtonWithTitle:@"生成测试文件" color:UIColor.systemBlueColor];
    [generate addTarget:self action:@selector(onGenerate:) forControlEvents:UIControlEventTouchUpInside];
    UIButton *remove = [self makeButtonWithTitle:@"删除测试文件" color:UIColor.systemRedColor];
    [remove addTarget:self action:@selector(onDelete:) forControlEvents:UIControlEventTouchUpInside];
    UIStackView *buttons = [[UIStackView alloc] initWithArrangedSubviews:@[generate, remove]];
    buttons.axis = UILayoutConstraintAxisHorizontal;
    buttons.distribution = UIStackViewDistributionFillEqually;
    buttons.spacing = 12;

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[title, hint, buttons]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 20;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:stack];
    UILayoutGuide *g = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [stack.centerYAnchor constraintEqualToAnchor:g.centerYAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:g.leadingAnchor constant:24],
        [stack.trailingAnchor constraintEqualToAnchor:g.trailingAnchor constant:-24],
    ]];
}

- (UIButton *)makeButtonWithTitle:(NSString *)title color:(UIColor *)color {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    [btn setTitle:title forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    btn.backgroundColor = [color colorWithAlphaComponent:0.12];
    [btn setTitleColor:color forState:UIControlStateNormal];
    btn.layer.cornerRadius = 12;
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    [btn.heightAnchor constraintEqualToConstant:52];
    return btn;
}

- (void)onGenerate:(UIButton *)sender {
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
