//
//  T3GateConfig.h - doro工具箱启动验证配置
//
//  改成你自己的 T3 后台配置。RSA 模式需要后台按 README 的 10 项配置。
//

#ifndef T3GateConfig_h
#define T3GateConfig_h

// 本地版本号（与服务端对比，沿用你压缩包 main.m 的值）
static NSString * const T3_LOCAL_VERSION = @"1000";

// 心跳间隔（秒）与连续失败上限
static const NSTimeInterval T3_HEARTBEAT_INTERVAL = 60.0;
static const int T3_MAX_HEARTBEAT_FAIL = 5;

// 卡密本地存储 key
static NSString * const T3_PREF_KEY_CARD = @"t3_saved_card";

// 验证页文案（Doro工具箱）
static NSString * const T3_GATE_LOGO       = @"Doro";
static NSString * const T3_GATE_TITLE      = @"Doro工具箱";
static NSString * const T3_GATE_SUBTITLE   = @"请输入卡密完成验证";
static NSString * const T3_GATE_FOOTER     = @"验证通过后进入 Doro工具箱";

// 目标被 hook 的类与方法（doro工具箱首页）
static NSString * const T3_HOOK_CLASS  = @"WQRootViewController";
static NSString * const T3_HOOK_SELECTOR = @"viewDidAppear:";

// 初始化调用码（RSA 模式）—— 来自新版 T3Example_iOS_Fullscreen
static NSString * const T3_LOGIN_CODE    = @"7BFFEF96CC453491";
static NSString * const T3_NOTICE_CODE   = @"6B4B137362EFCE70";
static NSString * const T3_VERSION_CODE  = @"C3892339B352E16B";
static NSString * const T3_HEARTBEAT_CODE = @"37D7292271A35FD9";
static NSString * const T3_APPKEY        = @"367df964d9abf633bc1e66bacf402cf1";
static NSString * const T3_RSA_PUBLIC_KEY =
    @"-----BEGIN PUBLIC KEY-----\n"
    "MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDDKdIDZTJMtvBMGjXKslbt3lcS\n"
    "bXrDoqEaHGgpR2sG2rjf2sd/uuS017BLJ/rGqpq0QjNhO1RlfBmYAgOofeqPwOD1\n"
    "th0LrhFK0vYB2V7MV+Ng4PcfX/tylMkY/YDQ79cFhCdhU1ENTqF+6z2ETRwC98n1\n"
    "n5xWvtPdqItluk9QNQIDAQAB\n"
    "-----END PUBLIC KEY-----";

#endif
