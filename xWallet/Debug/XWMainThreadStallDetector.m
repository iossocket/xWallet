//
//  XWMainThreadStallDetector.m
//  xWallet
//
//  Created by Xueliang Zhu on 20/3/26.
//

#if DEBUG

#import "XWDebugToolkit.h"
#import <CoreFoundation/CoreFoundation.h>

static const NSInteger kMaxStallRecords = 50;

@interface XWMainThreadStallDetector ()
@property (nonatomic, strong) NSThread *monitorThread;
@property (nonatomic, assign) CFRunLoopObserverRef observer;
@property (nonatomic, assign) CFRunLoopActivity currentActivity;
@property (nonatomic, strong) dispatch_semaphore_t semaphore;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *stallRecords;
@property (nonatomic, strong) dispatch_queue_t recordQueue;
@property (nonatomic, assign) NSInteger stallTotal;
@property (nonatomic, assign, getter=isMonitoring) BOOL monitoring;
@end

@implementation XWMainThreadStallDetector

+ (instancetype)shared {
    static XWMainThreadStallDetector *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[XWMainThreadStallDetector alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _stallThreshold = 0.05; // 50ms default
        _stallRecords = [NSMutableArray arrayWithCapacity:kMaxStallRecords];
        _recordQueue = dispatch_queue_create("com.xwallet.stall.record", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)resetRecords {
    self.currentActivity = 0;
    self.stallTotal = 0;
    dispatch_sync(self.recordQueue, ^{
        [self.stallRecords removeAllObjects];
    });
}

- (void)startMonitoring {
    if (self.isMonitoring) { return; }
    self.monitoring = YES;
    self.semaphore = dispatch_semaphore_create(0);
    [self resetRecords];

    // Register RunLoop observer on main thread
    __weak typeof(self) weakSelf = self;
    CFRunLoopObserverRef observer = CFRunLoopObserverCreateWithHandler(
        kCFAllocatorDefault,
        kCFRunLoopAllActivities,
        YES, // repeats
        0,   // order
        ^(CFRunLoopObserverRef obs, CFRunLoopActivity activity) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            strongSelf.currentActivity = activity;
            // Signal the semaphore whenever activity changes
            dispatch_semaphore_signal(strongSelf.semaphore);
        }
    );
    CFRunLoopAddObserver(CFRunLoopGetMain(), observer, kCFRunLoopCommonModes);
    self.observer = observer;

    // Monitor on a background thread
    self.monitorThread = [[NSThread alloc] initWithBlock:^{
        [self monitorLoop];
    }];
    self.monitorThread.name = @"com.xwallet.stall-detector";
    self.monitorThread.qualityOfService = NSQualityOfServiceUtility;
    [self.monitorThread start];
}

- (void)stopMonitoring {
    if (!self.isMonitoring) { return; }
    self.monitoring = NO;

    if (_observer) {
        CFRunLoopRemoveObserver(CFRunLoopGetMain(), _observer, kCFRunLoopCommonModes);
        CFRelease(_observer);
        _observer = nil;
    }

    [self.monitorThread cancel];
    if (self.semaphore) {
        dispatch_semaphore_signal(self.semaphore);
    }
    self.monitorThread = nil;
    self.semaphore = nil;
    self.currentActivity = 0;
}

- (void)monitorLoop {
    while (!NSThread.currentThread.isCancelled) {
        // Wait for the threshold duration
        long result = dispatch_semaphore_wait(
            self.semaphore,
            dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.stallThreshold * NSEC_PER_SEC))
        );

        if (result != 0) {
            // Timeout — main thread did not signal within threshold
            CFRunLoopActivity activity = self.currentActivity;
            if (activity == kCFRunLoopBeforeSources || activity == kCFRunLoopAfterWaiting) {
                // Main thread is stalled in a source/timer handler
                CFAbsoluteTime stallStart = CFAbsoluteTimeGetCurrent();

                // Wait again to measure total stall duration
                dispatch_semaphore_wait(self.semaphore, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)));
                CFTimeInterval stallDuration = CFAbsoluteTimeGetCurrent() - stallStart + self.stallThreshold;

                self.stallTotal++;

                NSDictionary *record = @{
                    @"timestamp": [NSDate date],
                    @"duration_ms": @(stallDuration * 1000),
                    @"activity": activity == kCFRunLoopBeforeSources ? @"beforeSources" : @"afterWaiting"
                };

                dispatch_async(self.recordQueue, ^{
                    [self.stallRecords addObject:record];
                    if (self.stallRecords.count > kMaxStallRecords) {
                        [self.stallRecords removeObjectAtIndex:0];
                    }
                });
            }
        }
    }
}

- (NSInteger)stallCount {
    return self.stallTotal;
}

- (NSArray<NSDictionary *> *)recentStalls {
    __block NSArray *copy;
    dispatch_sync(self.recordQueue, ^{
        copy = [self.stallRecords copy];
    });
    return copy;
}

- (void)dealloc {
    [self stopMonitoring];
}

@end
#endif
