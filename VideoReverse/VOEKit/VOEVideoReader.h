//
//  VOEVideoReader.h
//  VideoReverse
//
//  Created by qiyun on 2020/4/7.
//  Copyright © 2020 qiyun. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VOEVideo.h"
#import <CoreMedia/CoreMedia.h>
#import <AVFoundation/AVFoundation.h>
#import "VOEKit.h"

NS_ASSUME_NONNULL_BEGIN

@class VOEVideoReader;
@protocol VOESampleBufferDelegate <NSObject>

@optional
- (void)videoReader:(VOEVideoReader *)videoReader mediaType:(AVMediaType)mediaType didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer;

@end

@interface
VOEVideoReader : NSObject

- (id)initWithVideo:(VOEVideo *)video;

// Media output of delegate, get real time video and audio data
@property (weak, nonatomic) id<VOESampleBufferDelegate> delegate;

// Current loading the video handle
@property (strong, nonatomic, readonly, getter=getVideoHandle) VOEVideo *videoHandle;

// Reverse an media to new file and playable
@property (assign, nonatomic) BOOL reverse;

// Reading sample buffer data from AVAsset
- (BOOL)readerMediaWithPrepareBlock:(void (^) (void))prepareBlock completionHandler:(void (^) (CMSampleBufferRef sampleBuffer, AVMediaType mediaType))handler;

@end


@interface
VOEVideoReader (VOEVideoAssetReader)


// AVAssetReader provides services for obtaining media data from an asset.
@property (strong, nonatomic) AVAssetReader *assetReader;

// AVAssetReaderOutput is an abstract class that defines an interface for reading a single collection of samples of a common media type from an AVAssetReader.
@property (strong, nonatomic) AVAssetReaderOutput *videoReaderOutput;
@property (strong, nonatomic) AVAssetReaderOutput *audioReaderOutput;

// Output setting of decode propertis
@property (copy, nonatomic, readonly, getter=getVideoOutputSetting) NSDictionary    *videoOutputSetting;
@property (copy, nonatomic, readonly, getter=getAudioOutputSetting) NSDictionary    *audioOutputSetting;


// Start decompression video to sample buffer of audio or video
- (BOOL)startDecompressionVideoWithPrepareBlock:(void (^) (void))prepareBlock;

@end

NS_ASSUME_NONNULL_END
