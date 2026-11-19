//
//  DoroHeartbeat.m
//  用 T3 的 heartbeatWithKami 定时发心跳；单次失败即回调 onFailure（主线程）。
//  请求在后台线程，回调切回主线程，避免阻塞 UI。
//

#import "DoroHeartbeat.h"
#import "T3Verify.h"

@interface DoroHeartbeat ()
@property (nonatomic, strong) T3Verify *verify;
@property (nonatomic, copy) NSString *kami;
@property (nonatomic, copy) NSString *statecode;
@property (nonatomic, assign) NSTimeInterval interval;
@property (nonatomic, copy) void (^onFailure)(NSString *);
@property (nonatomic, strong, nullable) NSTimer *timer;
@property (nonatomic, assign) BOOL stopped;
@end

@implementation DoroHeartbeat

- (instancetype)initWithVerify:(T3Verify *)verify
                          kami:(NSString *)kami
                     statecode:(NSString *)statecode
                      interval:(NSTimeInterval)interval
                     onFailure:(void (^)(NSString *))onFailure {
    if ((self = [super init])) {
        _verify = verify;
        _kami = [kami copy];
        _statecode = [statecode copy];
        _interval = interval;
        _onFailure = [onFailure copy];
    }
    return self;
}

- (void)start {
    [self stop];
    self.stopped = NO;
    __weak typeof(self) wf = self;
    self.timer = [NSTimer scheduledTimerWithTimeInterval:self.interval
                                                 repeats:YES
                                                   block:^(NSTimer * _Nonnull t) {
        [wf fire];
    }];
    [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
    NSLog(@"[Heartbeat] started interval=%.0fs kami=%@", self.interval, self.kami.length ? @"saved" : @"empty");
}

- (void)stop {
    [self.timer invalidate];
    self.timer = nil;
    self.stopped = YES;
}

- (void)fire {
    if (self.stopped) return;
    NSString *kami = self.kami, *sc = self.statecode;
    if (!kami.length || !sc.length) return;
    __weak typeof(self) wf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (wf.stopped) return;
        T3Result *r = [wf.verify heartbeatWithKami:kami statecode:sc];
        BOOL ok = r.success;
        NSString *reason = r.error ?: r.msg ?: @"心跳失败";
        dispatch_async(dispatch_get_main_queue(), ^{
            if (wf.stopped) return;
            if (!ok) {
                NSLog(@"[Heartbeat] failed: %@", reason);
                [wf stop];
                if (wf.onFailure) wf.onFailure(reason);
            } else {
                NSLog(@"[Heartbeat] ok");
            }
        });
    });
}

- (void)dealloc {
    [self.timer invalidate];
}

@end
