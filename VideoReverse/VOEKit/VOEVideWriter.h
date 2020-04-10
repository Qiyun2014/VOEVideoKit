//
//  VOEVideWriter.h
//  VideoReverse
//
//  Created by qiyun on 2020/4/7.
//  Copyright © 2020 qiyun. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "VOEKit.h"

NS_ASSUME_NONNULL_BEGIN

@interface VOEVideWriter : NSObject

- (id)initWithURL:(NSURL *)outputUrl;

// Preset write media of bitrate and pixel size
@property (assign, nonatomic) NSInteger biterate;
@property (assign, nonatomic) CGSize naturesize;

// AVAssetWriter provides services for writing media data to a new file,
@property (strong, nonatomic) AVAssetWriter *assetWriter;

// Defines an interface for appending either new media samples or references to existing media samples packaged as CMSampleBuffer objects to a single track of the output file of an AVAssetWriter.
@property (strong, nonatomic) AVAssetWriterInput *videoAssetWriterInput;
@property (strong, nonatomic) AVAssetWriterInput *audioAssetWriterInput;

// Defines an interface for appending video samples packaged as CVPixelBuffer objects to a single AVAssetWriterInput object.
@property (strong, nonatomic) AVAssetWriterInputPixelBufferAdaptor  *inputPixelBufferAdaptor;

// Create file to document
+ (NSString *)createTempFileWithFormat:(NSString *)format;

// Start writer media data
- (void)startWriter;

// Prepare writer and ready for more data from block
- (void)requestForMoreMediaOfType:(AVMediaType)mediaType didWriteOnCompletionBlock:(void (^) (AVMediaType mediaType, CMSampleBufferRef sampleBuffer))finished;

// Start writer sample buffer to file
- (BOOL)writerInputSampleBuffer:(CMSampleBufferRef)sampleBuffer mediaType:(AVMediaType)mediaType;

@end

NS_ASSUME_NONNULL_END
