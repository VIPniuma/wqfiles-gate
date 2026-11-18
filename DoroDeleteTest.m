//
//  DoroDeleteTest.m
//  删除测试文件（纯逻辑，UI 由 DoroHomeViewController 负责）。
//  定位三角洲容器 → 用容器里真实特征名拼出「测试123」完整路径 → 先 grant 父目录 → wq_delete → 校验。
//

#import "DoroDeleteTest.h"
#import "DeltaForceLocator.h"
#import "WQAccess.h"
#import <sys/stat.h>
#import <errno.h>

static NSString * const kFeatureNames[] = { @"DeltaForce", @"Delta-Force" };
static NSString * const kFeatureKey  = @"deltaforce";
static NSString * const kTail = @"Saved/LuaDebug/LuaSource/DFM/BusinessEntrance";
static NSString * const kFile = @"测试123";

static NSString *wq_feature_key(NSString *s) {
    if (![s isKindOfClass:NSString.class]) return @"";
    NSMutableString *out = [NSMutableString stringWithCapacity:s.length];
    for (NSUInteger i = 0; i < s.length; i++) {
        unichar ch = [s characterAtIndex:i];
        if (ch >= 'A' && ch <= 'Z') ch = (unichar)(ch + ('a' - 'A'));
        if (ch >= 'a' && ch <= 'z') [out appendFormat:@"%c", (char)ch];
    }
    return out;
}

@implementation DoroDeleteTest

+ (void)runWithHost:(UIViewController * __unused)host
         completion:(void (^)(NSString *, NSString *))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *diag = nil;
        NSString *root = [DeltaForceLocator findSavedRoot:&diag];
        NSString *title, *msg;
        if (!root) {
            title = @"未找到三角洲容器";
            msg = diag ?: @"未知原因";
        } else {
            NSString *docs = [root stringByAppendingPathComponent:@"Documents"];
            wq_grant(root); wq_grant(docs);
            NSArray *entries = wq_list(docs, nil);
            NSString *name = nil;
            struct stat st;
            if (entries) {
                for (NSString *n in entries) {
                    if ([n isKindOfClass:NSString.class] && [wq_feature_key(n) isEqualToString:kFeatureKey]) {
                        name = n; break;
                    }
                }
            } else {
                NSUInteger count = sizeof(kFeatureNames) / sizeof(kFeatureNames[0]);
                for (NSUInteger i = 0; i < count; i++) {
                    NSString *probe = [[docs stringByAppendingPathComponent:kFeatureNames[i]]
                                       stringByAppendingPathComponent:kTail];
                    if (wq_stat(probe, &st) == 0 && S_ISDIR(st.st_mode)) { name = kFeatureNames[i]; break; }
                }
            }
            if (!name) {
                title = @"删除失败";
                msg = @"容器里没有特征目录，无需删除";
            } else {
                NSString *dir = [[docs stringByAppendingPathComponent:name] stringByAppendingPathComponent:kTail];
                NSString *file = [dir stringByAppendingPathComponent:kFile];
                // 存在性判断用读回内容，不用 wq_stat（沙盒逃逸下对新文件假失败，会误报"文件不存在"）
                wq_grant(dir);
                NSString *before = [NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil];
                if (!before.length) {
                    // 读不到也可能只是 token 没覆盖，再 grant 特征目录与容器根试一次
                    wq_grant([docs stringByAppendingPathComponent:name]);
                    wq_grant(root);
                    wq_grant(dir);
                    before = [NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil];
                }
                // 无论读不读得到都尝试删除：wq_delete 内部自带 grant/check 重试，返回值为准。
                wq_grant(dir);
                NSString *delErr = nil;
                BOOL ok = wq_delete(file, &delErr);
                // 复查用读回：读不到 == 已删除；若之前能读到、现在读不到也可确认
                wq_grant(dir);
                NSString *after = [NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil];
                BOOL gone = (after.length == 0);
                if (ok || (before.length && gone)) {
                    title = @"删除成功";
                } else if (!before.length && !ok && gone) {
                    title = @"删除成功";   // 本来就读不到，wq_delete 也说没有，视为已不存在
                } else {
                    title = @"删除失败";
                }
                msg = [NSString stringWithFormat:@"文件：%@（原读回 %lu 字）\nwq_delete=%@（%@）\n复查=%@",
                       file, (unsigned long)before.length, ok ? @"成功" : @"失败", delErr ?: @"无",
                       gone ? @"读不到，已删除" : [NSString stringWithFormat:@"仍读到 %lu 字", (unsigned long)after.length]];
            }
        }
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(title, msg); });
    });
}

@end
