//
//  XWDebugToolkit.h
//  xWallet
//
//  Created by Xueliang Zhu on 17/3/26.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// FPS monitor using CADisplayLink. Auto-activates via +load.
@interface XWFPSMonitor : NSObject

+ (instancetype)shared;

@property (nonatomic, readonly) double currentFPS;
@property (nonatomic, readonly) NSInteger droppedFrameCount;
@property (nonatomic, readonly) NSInteger totalFrameCount;

- (double)droppedFrameRate;

@end

/// Network request interceptor. Swizzles URLSession in +load.
@interface XWNetworkInterceptor : NSObject

+ (instancetype)shared;

@property (nonatomic, readonly) NSArray<NSDictionary *> *recentLogs;

@end

NS_ASSUME_NONNULL_END
