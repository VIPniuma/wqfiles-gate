//
//  DoroSBCardBridge.m
//  读卡密：遍历容器 → <容器>/Library/Preferences/cz.kolbi.wqfiles.plist → t3_saved_card。
//  SpringBoard 无沙盒，直接文件读；plist 可能与 NSUserDefaults 缓存不同步，
//  因此用 NSDictionary 读文件而非 initWithSuiteName（后者在 SB 里拿不到 App 的 suite）。
//

#import "DoroSBCardBridge.h"
#import "DoroSBConfig.h"

@implementation DoroSBCardBridge

+ (NSString *)readCard {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *uuids = [fm contentsOfDirectoryAtPath:SB_DATA_ROOT error:nil] ?: @[];
    for (NSString *u in uuids) {
        NSString *plist = [[SB_DATA_ROOT stringByAppendingPathComponent:u]
                           stringByAppendingPathComponent:SB_CARD_PLIST_SUFFIX];
        NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:plist];
        NSString *card = d[SB_CARD_KEY];
        if ([card isKindOfClass:NSString.class] && card.length) {
            NSLog(@"[DoroSB] card from %@", plist);
            return card;
        }
    }
    return nil;
}

@end
