//
//  DoroScriptCleaner.m
//  延迟删除：dispatch_after 到点后在后台队列 wq_grant 父目录 -> wq_delete -> 读回校验。
//  存在性一律以读回为准（wq_stat 在沙盒逃逸下假失败），与 DoroDeleteTest 同一套判断。
//

#import "DoroScriptCleaner.h"
#import "WQAccess.h"
#import <sys/stat.h>
#import <errno.h>

@implementation DoroScriptCleaner

+ (void)deletePath:(NSString *)path
        afterDelay:(NSTimeInterval)delay
        completion:(void (^)(BOOL, NSString *))completion {
    if (!path.length) {
        if (completion) completion(NO, @"路径为空");
        return;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(MAX(0, delay) * NSEC_PER_SEC)),
                   dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *parent = path.stringByDeletingLastPathComponent;
        // 删前先读一次（用于确认"确实放进去过"）
        wq_grant(parent);
        NSData *before = [NSData dataWithContentsOfFile:path];

        wq_grant(parent);
        NSString *delErr = nil;
        BOOL delOK = wq_delete(path, &delErr);

        // 复查：读不到 == 已删掉（wq_stat 不可信）
        wq_grant(parent);
        NSData *after = [NSData dataWithContentsOfFile:path];
        BOOL gone = (after.length == 0);
        BOOL ok = (gone && (delOK || before.length > 0));
        NSString *msg = [NSString stringWithFormat:@"延迟 %.0f 秒删除 %@\n删前 %lu 字节 / 删后 %@\nwq_delete=%@（%@）",
                         delay, path.lastPathComponent,
                         (unsigned long)before.length,
                         gone ? @"读不到（已删除）" : [NSString stringWithFormat:@"仍读到 %lu 字节", (unsigned long)after.length],
                         delOK ? @"成功" : @"失败", delErr ?: @"无"];
        NSLog(@"[Cleaner] %@", msg);
        if (completion) completion(ok, msg);
    });
}

@end
