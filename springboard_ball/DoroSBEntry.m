//
//  DoroSBEntry.m
//  tweak 入口：dylib 被 SpringBoard 加载时 constructor 触发，主队列安装悬浮球。
//  不 hook 方法、不改任何游戏内存；只在 SpringBoard 进程加一个悬浮 window。
//

#import <Foundation/Foundation.h>
#import "DoroSBBall.h"

__attribute__((constructor)) static void doro_sb_init(void) {
    @autoreleasepool {
        NSLog(@"[DoroSB] loaded into %@", NSBundle.mainBundle.bundleIdentifier);
        dispatch_async(dispatch_get_main_queue(), ^{
            [[DoroSBBall shared] install];
        });
    }
}
