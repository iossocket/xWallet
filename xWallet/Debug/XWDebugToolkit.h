//
//  XWDebugToolkit.h
//  xWallet
//
//  Created by Xueliang Zhu on 17/3/26.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// FPS monitor using CADisplayLink. Starts when the debug overlay is shown.
@interface XWFPSMonitor : NSObject

+ (instancetype)shared;

@property (nonatomic, readonly) double currentFPS;
@property (nonatomic, readonly) NSInteger droppedFrameCount;
@property (nonatomic, readonly) NSInteger totalFrameCount;

- (void)startMonitoring;
- (void)stopMonitoring;
- (double)droppedFrameRate;

@end

/// Main thread stall detector using RunLoop observer. Starts when the debug overlay is shown.
@interface XWMainThreadStallDetector : NSObject

+ (instancetype)shared;

/// Stall threshold in seconds (default 0.05 = 50ms).
@property (nonatomic, assign) CFTimeInterval stallThreshold;

/// Total stall count since monitoring started.
@property (nonatomic, readonly) NSInteger stallCount;

/// Most recent stall records (max 50).
@property (nonatomic, readonly) NSArray<NSDictionary *> *recentStalls;

- (void)startMonitoring;
- (void)stopMonitoring;

@end

NS_ASSUME_NONNULL_END
