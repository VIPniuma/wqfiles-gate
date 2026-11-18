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

// 验证页文案（改成你的品牌）
static NSString * const T3_GATE_LOGO       = @"doro";
static NSString * const T3_GATE_TITLE      = @"doro工具箱";
static NSString * const T3_GATE_SUBTITLE   = @"请输入卡密完成验证";
static NSString * const T3_GATE_FOOTER     = @"验证通过后进入 doro工具箱";

// 目标被 hook 的类与方法（doro工具箱首页）
static NSString * const T3_HOOK_CLASS  = @"WQRootViewController";
static NSString * const T3_HOOK_SELECTOR = @"viewDidAppear:";

// 初始化调用码（RSA 模式）
static NSString * const T3_LOGIN_CODE    = @"E9CCBAB031E1203D";
static NSString * const T3_NOTICE_CODE   = @"60D71FEA622E9C2C";
static NSString * const T3_VERSION_CODE  = @"AC6C49CE1A1D85F5";
static NSString * const T3_HEARTBEAT_CODE = @"3CC7AFE5CD4A6297";
static NSString * const T3_APPKEY        = @"e9032ec5bd602df5e1c6955beae45af5";
static NSString * const T3_RSA_PUBLIC_KEY =
    @"-----BEGIN PUBLIC KEY-----\n"
    "MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDhNS2T2jaeoZ1hBDmg0bqkaXmZ\n"
    "ea72oLjIbgwRiXoIukmj8Yyp5pL+cKEesVsCADaO/x2rdmFQD40atZIXWWA65ag0\n"
    "plv7zm6+nDTZUdFzgWjNi316wl1qOiMsJjmLKq0tf7ebqt0WMx5t+XMHxt24BLfz\n"
    "bclR20INweECMKLIhQIDAQAB\n"
    "-----END PUBLIC KEY-----";

#endif
