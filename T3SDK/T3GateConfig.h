//
//  T3GateConfig.h - doro工具箱启动验证配置
//
//  改成你自己的 T3 后台配置。RSA 模式需要后台按 README 的 10 项配置。
//
//  加固：调用码/appkey/RSA key/卡密 key/品牌串改为 DORO_* 解密宏，
//  明文只存在于 tools/ipa_hardener/strings_config.json，二进制里是混淆字节。
//  数值常量与纯 UI 文案保持明文，不影响使用点代码。
//

#ifndef T3GateConfig_h
#define T3GateConfig_h

#import "DoroStringTable.h"

// 本地版本号（与服务端对比，沿用你压缩包 main.m 的值）
#define T3_LOCAL_VERSION DORO_T3_LOCAL_VERSION

// 心跳间隔（秒）与连续失败上限（数值，无需混淆）
static const NSTimeInterval T3_HEARTBEAT_INTERVAL = 60.0;
static const int T3_MAX_HEARTBEAT_FAIL = 5;

// 卡密本地存储 key
#define T3_PREF_KEY_CARD DORO_T3_PREF_KEY_CARD

// 验证页文案（Doro工具箱）
#define T3_GATE_LOGO       DORO_T3_GATE_LOGO
#define T3_GATE_TITLE      DORO_T3_GATE_TITLE
static NSString * const T3_GATE_SUBTITLE   = @"请输入卡密完成验证";
static NSString * const T3_GATE_FOOTER     = @"验证通过后进入 Doro工具箱";

// 目标被 hook 的类与方法（doro工具箱首页）
#define T3_HOOK_CLASS  DORO_T3_HOOK_CLASS
static NSString * const T3_HOOK_SELECTOR = @"viewDidAppear:";

// 初始化调用码（RSA 模式）—— 来自新版 T3Example_iOS_Fullscreen
#define T3_LOGIN_CODE     DORO_T3_LOGIN_CODE
#define T3_NOTICE_CODE    DORO_T3_NOTICE_CODE
#define T3_VERSION_CODE   DORO_T3_VERSION_CODE
#define T3_HEARTBEAT_CODE DORO_T3_HEARTBEAT_CODE
#define T3_APPKEY         DORO_T3_APPKEY
#define T3_RSA_PUBLIC_KEY DORO_T3_RSA_PUBLIC_KEY

#endif
