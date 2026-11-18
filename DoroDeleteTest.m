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
                struct stat fst;
                BOOL exists = wq_stat(file, &fst) == 0;
                if (!exists) {
                    title = @"没有测试文件";
                    msg = [NSString stringWithFormat:@"文件不存在：%@", file];
                } else {
                    wq_grant(dir);   // grant 父目录，wq_delete 内部 lstat/unlink 走 token 重试
                    NSString *delErr = nil;
                    BOOL ok = wq_delete(file, &delErr);
                    // 校验：以 lstat 直查为准（wq_stat 在 token 消费后可能假失败）
                    struct stat after = {0};
                    BOOL gone = lstat(file.fileSystemRepresentation, &after) != 0;
                    title = (ok || gone) ? @"删除成功" : @"删除失败";
                    msg = [NSString stringWithFormat:@"文件：%@\nwq_delete=%@（%@）\n复查=%@",
                           file, ok ? @"成功" : @"失败", delErr ?: @"无", gone ? @"已不存在" : @"仍存在"];
                }
            }
        }
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(title, msg); });
    });
}

@end
