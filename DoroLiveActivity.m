//
//  DoroLiveActivity.m
//  灵动岛 ObjC 包装：调用 Swift 桥 doro_live_start / doro_live_end。
//  WQ_SCREENSHOT_MODE（模拟器截图）下用空实现，避免依赖 Swift 链接。
//

#import "DoroLiveActivity.h"

#ifndef WQ_SCREENSHOT_MODE
// Swift @_cdecl 暴露的 C 符号
extern int doro_live_start(const char *title, const char *text);
extern void doro_live_end(void);
#endif

@implementation DoroLiveActivity

+ (BOOL)startWithTitle:(NSString *)title text:(NSString *)text {
#ifndef WQ_SCREENSHOT_MODE
    return doro_live_start(title.UTF8String, text.UTF8String) == 1;
#else
    (void)title; (void)text; return NO;
#endif
}

+ (void)end {
#ifndef WQ_SCREENSHOT_MODE
    doro_live_end();
#endif
}

@end
