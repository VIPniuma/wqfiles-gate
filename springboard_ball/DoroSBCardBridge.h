//
//  DoroSBCardBridge.h
//  卡密桥接：SpringBoard 特权进程直接读工具箱容器 Preferences plist 里的 t3_saved_card。
//  不需要 App Group / worse_query（SpringBoard 无沙盒）。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DoroSBCardBridge : NSObject

// 遍历所有 Data/Application/<UUID>，读 cz.kolbi.wqfiles.plist 的 t3_saved_card，
// 返回第一个非空卡密；找不到返回 nil。
+ (NSString * _Nullable)readCard;

@end

NS_ASSUME_NONNULL_END
