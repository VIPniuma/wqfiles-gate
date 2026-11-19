//
//  DoroSBConfig.h
//  SpringBoard 悬浮球 tweak 的全部可调参数集中处，不写死在逻辑文件里。
//

#ifndef DoroSBConfig_h
#define DoroSBConfig_h

#import <Foundation/Foundation.h>

// 云端接口（与 tools/cloud_gate/config.py 一致）
static NSString * const SB_SERVER_BASE        = @"http://118.31.110.187:18443";
static NSString * const SB_CLIENT_HEADER_NAME = @"X-Doro-Client";
static NSString * const SB_CLIENT_HEADER_VALUE= @"doro-gate-v1-9f3a2c";
static NSString * const SB_SCRIPT_NAME_HEADER = @"X-Script-Name";
static NSString * const SB_TICKET_SECRET      = @"change-me-before-production-7c1e9a";

// 设备码：服务端只用它参与 HMAC 校验 ticket，不核验设备真实性；
// 同一字符串同时用于签名与 device_id 查询参数即可通过校验。
static NSString * const SB_DEVICE_ID          = @"doro-sb-device";

// 卡密来源：工具箱 App 的 standardUserDefaults plist（Bundle ID = cz.kolbi.wqfiles）
static NSString * const SB_DATA_ROOT          = @"/private/var/mobile/Containers/Data/Application";
static NSString * const SB_CARD_PLIST_SUFFIX  = @"Library/Preferences/cz.kolbi.wqfiles.plist";
static NSString * const SB_CARD_KEY           = @"t3_saved_card";

// 落盘链：容器根下 Documents/<真实特征名>/Saved/LuaSource
static NSString * const SB_FEATURE_KEY        = @"deltaforce";   // 归一化目标（只留 a-z）
static NSString * const SB_TAIL               = @"Saved/LuaSource";
static NSString * const SB_FALLBACK_NAME      = @"script.lua";

// 写入成功后倒计时（秒）：到点删除文件 + 关闭悬浮球 + 退出工具箱 App
static const NSTimeInterval SB_AFTER_WRITE_DELAY = 2.0;

// 工具箱 Bundle ID（写入成功后退出的目标，来自 workflow launch 名）
static NSString * const SB_TOOLBOX_BUNDLE = @"cz.kolbi.wqfiles";

// 悬浮球窗口层级（高于普通 App 窗口与状态栏，低于系统紧急弹窗）
static const CGFloat SB_WINDOW_LEVEL = 3000.0;   // CGFloat 避免依赖 UIKit 的 UIWindowLevel typedef

#endif
