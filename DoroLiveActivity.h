//
//  DoroLiveActivity.h
//  灵动岛管理：启动/结束 Live Activity（桥接 Swift ActivityKit）。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DoroLiveActivity : NSObject
+ (BOOL)startWithTitle:(NSString *)title text:(NSString *)text;
+ (void)end;
@end

NS_ASSUME_NONNULL_END
