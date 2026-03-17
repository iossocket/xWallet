//
//  XWDebugToolkit.m
//  xWallet
//
//  Created by Xueliang Zhu on 17/3/26.
//

#if DEBUG

#import "XWDebugToolkit.h"
#import <QuartzCore/QuartzCore.h>

static const NSInteger kWindowSize = 120; // ~2 seconds at 60fps

// Ring buffer
@interface XWFPSMonitor () {
    CFTimeInterval _ringBuffer[120]; // must match kWindowSize
    NSInteger _head;                 // next write position
    NSInteger _count;                // filled slots (0..kWindowSize)
    CFTimeInterval _runningSum;      // sum of all values in the ring
}
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, assign) CFTimeInterval lastTimestamp;
@property (nonatomic, assign) NSInteger droppedFrames;
@property (nonatomic, assign) NSInteger totalFrames;
@end

@implementation XWFPSMonitor

+ (void)load {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[XWFPSMonitor shared] startMonitoring];
    });
}

+ (instancetype)shared {
    static XWFPSMonitor *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[XWFPSMonitor alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        memset(_ringBuffer, 0, sizeof(_ringBuffer));
        _head = 0;
        _count = 0;
        _runningSum = 0;
    }
    return self;
}

- (void)startMonitoring {
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick:)];
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)tick:(CADisplayLink *)link {
    if (self.lastTimestamp == 0) {
        self.lastTimestamp = link.timestamp;
        return;
    }

    CFTimeInterval duration = link.timestamp - self.lastTimestamp;
    self.lastTimestamp = link.timestamp;
    self.totalFrames++;

    if (_count == kWindowSize) {
        _runningSum -= _ringBuffer[_head];
    }
    _ringBuffer[_head] = duration;
    _runningSum += duration;
    _head = (_head + 1) % kWindowSize;
    if (_count < kWindowSize) { _count++; }

    if (duration > (1.0 / 55.0)) {
        self.droppedFrames++;
    }
}

- (double)currentFPS {
    if (_count == 0 || _runningSum <= 0) return 0;
    return (double)_count / _runningSum;
}

- (NSInteger)droppedFrameCount {
    return self.droppedFrames;
}

- (NSInteger)totalFrameCount {
    return self.totalFrames;
}

- (double)droppedFrameRate {
    if (self.totalFrames == 0) return 0;
    return (double)self.droppedFrames / (double)self.totalFrames;
}

@end

#endif
