//
//  DoroPIP.m
//  画中画：AVPlayer 播放一段运行时生成的纯色短视频（自带，无外部素材），
//  AVPictureInPictureController 在退桌面时显示小窗。点击小窗系统恢复 App，
//  走 restoreUserInterfaceForPictureInPictureStopWithCompletionHandler -> onRestore。
//  依赖：AVKit / AVFoundation / CoreVideo / CoreMedia。
//

#import "DoroPIP.h"
#import <AVKit/AVKit.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreMedia/CoreMedia.h>

@interface DoroPIP () <AVPictureInPictureControllerDelegate>
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerLayer *playerLayer;
@property (nonatomic, strong) UIView *hostView;
@property (nonatomic, strong) AVPictureInPictureController *pip;
@end

@implementation DoroPIP

+ (instancetype)shared {
    static DoroPIP *o;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ o = [self new]; });
    return o;
}

- (BOOL)isActive {
    return self.pip && self.pip.isPictureInPictureActive;
}

// 生成一段 4 秒 320x240 粉色视频到临时文件（H264，纯色，开销极小）。
- (NSURL *)makeSolidVideo {
    NSURL *url = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"doro_pip.mp4"]];
    [[NSFileManager defaultManager] removeItemAtURL:url error:nil];

    AVAssetWriter *writer = [[AVAssetWriter alloc] initWithURL:url fileType:AVFileTypeMPEG4 error:nil];
    NSDictionary *settings = @{ AVVideoCodecKey: AVVideoCodecTypeH264,
                                AVVideoWidthKey: @320, AVVideoHeightKey: @240,
                                AVVideoCompressionPropertiesKey: @{ AVVideoAverageBitRateKey: @200000 } };
    AVAssetWriterInput *input = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:settings];
    AVAssetWriterInputPixelBufferAdaptor *adaptor =
        [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:input
                                                             sourcePixelBufferAttributes:@{ (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA) }];
    [writer addInput:input];
    [writer startWriting];
    [writer startSessionAtSourceTime:kCMTimeZero];

    // 每帧填充 BGRA(0xFF,0x9B,0xD8,1.0) -> 粉色
    NSInteger fps = 4, frames = fps * 4;
    for (NSInteger i = 0; i < frames; i++) {
        @autoreleasepool {
            CVPixelBufferRef buf = NULL;
            CVPixelBufferCreate(kCFAllocatorDefault, 320, 240, kCVPixelFormatType_32BGRA, NULL, &buf);
            CVPixelBufferLockBaseAddress(buf, 0);
            uint8_t *base = CVPixelBufferGetBaseAddress(buf);
            size_t stride = CVPixelBufferGetBytesPerRow(buf);
            for (int y = 0; y < 240; y++) {
                uint8_t *row = base + y * stride;
                for (int x = 0; x < 320; x++) {
                    row[x * 4 + 0] = 0xD8;  // B
                    row[x * 4 + 1] = 0x9B;  // G
                    row[x * 4 + 2] = 0xFF;  // R
                    row[x * 4 + 3] = 0xFF;  // A
                }
            }
            CVPixelBufferUnlockBaseAddress(buf, 0);
            CMTime t = CMTimeMake((int64_t)i, (int32_t)fps);
            while (!adaptor.assetWriterInput.isReadyForMoreMediaData) [NSThread sleepForTimeInterval:0.01];
            [adaptor appendPixelBuffer:buf withPresentationTime:t];
            CVPixelBufferRelease(buf);
        }
    }
    [input markAsFinished];
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    [writer finishWritingWithCompletionHandler:^{ dispatch_semaphore_signal(sem); }];
    dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)));
    return url;
}

- (BOOL)start {
    if (![AVPictureInPictureController isPictureInPictureSupported]) return NO;
    if (self.pip) [self stop];

    NSURL *video = [self makeSolidVideo];
    AVPlayerItem *item = [AVPlayerItem playerItemWithURL:video];
    item.loopPlayback = YES;   // 循环，避免播完退出 PiP
    self.player = [AVPlayer playerWithPlayerItem:item];

    // PiP 要求 playerLayer 挂在窗口层级里；用 1x1 透明 view 放在 keyWindow 上。
    UIWindow *key = nil;
    for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
        if ([s isKindOfClass:UIWindowScene.class] && s.activationState == UISceneActivationStateForegroundActive) {
            for (UIWindow *w in ((UIWindowScene *)s).windows) if (w.isKeyWindow) { key = w; break; }
        }
    }
    if (!key) return NO;
    UIView *host = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 1, 1)];
    host.alpha = 0.01;
    host.userInteractionEnabled = NO;
    [key addSubview:host];
    self.hostView = host;

    AVPlayerLayer *layer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    layer.frame = host.bounds;
    layer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [host.layer addSublayer:layer];
    self.playerLayer = layer;

    self.pip = [[AVPictureInPictureController alloc] initWithPlayerLayer:layer];
    self.pip.delegate = self;
    [self.player play];

    // startPictureInPicture 需等 playerLayer 就绪，延迟一点在主队列启动
    __weak typeof(self) wf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if ([wf.pip isPictureInPicturePossible] && !wf.pip.isPictureInPictureActive) {
            [wf.pip startPictureInPicture];
        }
    });
    return YES;
}

- (void)stop {
    if (self.pip.isPictureInPictureActive) [self.pip stopPictureInPicture];
    [self.player pause];
    [self.playerLayer removeFromSuperlayer];
    [self.hostView removeFromSuperview];
    self.pip = nil;
    self.player = nil;
    self.playerLayer = nil;
    self.hostView = nil;
}

#pragma mark - AVPictureInPictureControllerDelegate

// 点 PiP 小窗恢复 App 时，系统调这个来还原界面 —— 作为"点击回到工具箱"的准确信号。
- (void)pictureInPictureController:(AVPictureInPictureController *)controller
restoreUserInterfaceForPictureInPictureStopWithCompletionHandler:(void (^)(BOOL))completionHandler {
    completionHandler(YES);
    __weak typeof(self) wf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (wf.onRestore) wf.onRestore();
    });
}

@end
