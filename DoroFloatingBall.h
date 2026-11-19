//
//  DoroFloatingBall.h
//  悬浮球：显示后可拖动，点击触发云端脚本写入。
//  写入完成后由 DoroScriptCleaner 延迟 10 秒自动删除刚写入的文件。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DoroFloatingBall : NSObject

+ (instancetype)shared;

// 显示/隐藏悬浮球（独立高层级 window，跨页面可见，不抢 keyWindow）。
- (void)show;
- (void)hide;
- (BOOL)isShowing;

@end

NS_ASSUME_NONNULL_END
