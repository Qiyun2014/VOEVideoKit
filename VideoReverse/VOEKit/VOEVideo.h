//
//  VOEVideo.h
//  VideoReverse
//
//  Created by qiyun on 2020/4/7.
//  Copyright © 2020 qiyun. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface VOEVideo : NSObject

+ (id)videoForURL:(NSURL *)url;
- (id)initWithVideoForURL:(NSURL *)url;


// Media url
@property (nonatomic, copy) NSURL *url;

// Current resource file of format
@property (nonatomic, copy) NSString *format;

// File memory size
@property (nonatomic, assign) size_t fileSize;

// Media playable of time
@property (nonatomic, assign) float duration;

// Media of video resolution
@property (nonatomic, assign) CGSize naturalSize;

// Current media of asset
@property (readonly, nonatomic, getter=getAsset) AVAsset *asset;

// Output media trakc of audio or video
@property (readonly, nonatomic, getter=getVideoTrack) AVAssetTrack *videoTrack;
@property (readonly, nonatomic, getter=getAudioTrack) AVAssetTrack *audioTrack;

// Returns a series of UIImages for an asset at or near the specified times.
- (void)thumbnailImageOfNumber:(NSInteger)number imageSize:(CGSize)size completionHandle:(void (^)(NSArray *))handle;

@end

NS_ASSUME_NONNULL_END
