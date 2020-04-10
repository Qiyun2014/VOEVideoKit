//
//  VOEVideWriter.m
//  VideoReverse
//
//  Created by qiyun on 2020/4/7.
//  Copyright © 2020 qiyun. All rights reserved.
//

#import "VOEVideWriter.h"

NSString *kObserverWriterOutputStatus = @"assetWriter.status";
typedef void (^WriterReadyOnBlock) (AVMediaType mediaType, CMSampleBufferRef sampleBuffer);

@interface VOEVideWriter ()

@property (copy, nonatomic) NSURL *outputURL;
@property (copy, nonatomic) WriterReadyOnBlock writeReadyOnBlock;

@end

@implementation VOEVideWriter {
    dispatch_queue_t    _videoReadyForMediaQueue;
    dispatch_queue_t    _audioReadyForMediaQueue;
}

- (id)initWithURL:(NSURL *)outputUrl {
    if (self = [super init]) {
        self.outputURL = outputUrl;
    }
    return self;
}


#pragma mark    -   get method

// Set video decode of properties, include framerate, bitrate, resolution, deninse and so on.
- (NSDictionary *)videoCompressionOutputSetting {
    return @{AVVideoCodecTypeH264               : AVVideoH264EntropyModeCABAC,
             AVVideoAllowFrameReorderingKey     : @NO,
             AVVideoAverageBitRateKey           : @(self.naturesize.width * self.naturesize.height * 2 / 1024 * 1.5),
             AVVideoMaxKeyFrameIntervalKey      : @(10),
             AVVideoProfileLevelKey             : AVVideoProfileLevelH264MainAutoLevel,
    };
}


- (NSDictionary *)audioCompressionOutputSetting {
    AudioChannelLayout stereoChannelLayout = {
        .mChannelLayoutTag = kAudioChannelLayoutTag_Stereo,
        .mChannelBitmap = 0,
        .mNumberChannelDescriptions = 0
    };
    NSData *channelLayoutAsData = [NSData dataWithBytes:&stereoChannelLayout length:offsetof(AudioChannelLayout, mChannelDescriptions)];
    return @{AVFormatIDKey                      : @(kAudioFormatMPEG4AAC),
             AVNumberOfChannelsKey              : @(2),
             AVSampleRateKey                    : @(44100),
             AVChannelLayoutKey                 : channelLayoutAsData,
             AVEncoderBitRateKey                : @(128000),
             AVEncoderAudioQualityKey           : @(AVAudioQualityHigh),
    };
}


- (dispatch_queue_t)writeQueueWithMediaType:(AVMediaType)mediaType {
    return (mediaType == AVMediaTypeAudio) ? _audioReadyForMediaQueue : _videoReadyForMediaQueue;
}


- (NSDictionary *)outputSettingWithMediaType:(AVMediaType)mediaType {
    NSDictionary *videoOutputSetting = @{AVVideoCodecKey    : AVVideoCodecTypeH264,
                                         AVVideoWidthKey    : @(self.naturesize.width),
                                         AVVideoHeightKey   : @(self.naturesize.height),
                                         //AVVideoCompressionPropertiesKey : [self videoCompressionOutputSetting],
    };
    return (mediaType == AVMediaTypeAudio) ? [self audioCompressionOutputSetting] : videoOutputSetting;
}


- (NSDictionary *)pixelBufferAttributes {
    return @{(NSString *)kCVPixelBufferPixelFormatTypeKey                   : @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange),
             (NSString *)kCVPixelBufferCGBitmapContextCompatibilityKey      : @true,
             (NSString *)kCVPixelBufferBytesPerRowAlignmentKey              : @(self.naturesize.width * 4),
             (NSString *)kCVPixelBufferWidthKey                             : @(self.naturesize.width),
             (NSString *)kCVPixelBufferHeightKey                            : @(self.naturesize.height),
             (NSString *)kCVPixelBufferMetalCompatibilityKey                : @true,
    };
}


- (AVAssetWriter *)assetWriter {
    if (!_assetWriter) {
        NSError *error;
        _assetWriter = [AVAssetWriter assetWriterWithURL:self.outputURL fileType:AVFileTypeMPEG4 error:&error];
        _assetWriter.shouldOptimizeForNetworkUse = YES;
        // Support hls fragment and set interval time
        // _assetWriter.movieFragmentInterval = CMTimeMakeWithSeconds(10.0, 1000);
        // Support quick playable
        _assetWriter.shouldOptimizeForNetworkUse = YES;
        if ([_assetWriter canAddInput:self.videoAssetWriterInput] && self.inputPixelBufferAdaptor.pixelBufferPool != NULL) {
            [_assetWriter addInput:self.videoAssetWriterInput];
        }
        if ([_assetWriter canAddInput:self.audioAssetWriterInput]) {
            // [_assetWriter addInput:self.audioAssetWriterInput];
        }
        [self addObserver:self forKeyPath:kObserverWriterOutputStatus options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:NULL];
    }
    return _assetWriter;
}


- (AVAssetWriterInput *)videoAssetWriterInput {
    if (!_videoAssetWriterInput) {
        _videoReadyForMediaQueue = dispatch_queue_create("voe.videoWriter.input", DISPATCH_QUEUE_SERIAL);
        _videoAssetWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:[self outputSettingWithMediaType:AVMediaTypeVideo]];
        _videoAssetWriterInput.expectsMediaDataInRealTime = NO;
    }
    return _videoAssetWriterInput;
}


- (AVAssetWriterInput *)audioAssetWriterInput {
    if (!_audioAssetWriterInput) {
        _audioReadyForMediaQueue = dispatch_queue_create("voe.audioWriter.input", DISPATCH_QUEUE_SERIAL);
        _audioAssetWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:[self outputSettingWithMediaType:AVMediaTypeAudio]];
        _audioAssetWriterInput.expectsMediaDataInRealTime = NO;
    }
    return _audioAssetWriterInput;
}


- (AVAssetWriterInput *)getWriterInputForMediaType:(AVMediaType)mediaType {
    return (mediaType == AVMediaTypeVideo) ? self.videoAssetWriterInput : self.audioAssetWriterInput;
}


- (AVAssetWriterInputPixelBufferAdaptor *)inputPixelBufferAdaptor {
    if (!_inputPixelBufferAdaptor) {
        _inputPixelBufferAdaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:self.videoAssetWriterInput
                                                                                                    sourcePixelBufferAttributes:[self pixelBufferAttributes]];
    }
    return _inputPixelBufferAdaptor;
}


#pragma mark    -   private method

- (void)startWriter {
    // Decide to status is writing, or reset assetWrite
    if (self.assetWriter.status != AVAssetWriterStatusWriting) {
        if ([self.assetWriter startWriting]) {
            [self.assetWriter startSessionAtSourceTime:kCMTimeZero];
        } else {
            NSLog(@"Start writing error = %@", self.assetWriter.error);
        }
    }
}


#pragma mark    -   public method

+ (NSString *)createTempFileWithFormat:(NSString *)format {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd-HH-mm-ss"];
    NSString *dateTime = [formatter stringFromDate:[NSDate date]];
    NSString *fileName = [NSString stringWithFormat:@"%ld-%@.%@", random() % 10^5,dateTime, format];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *file = [paths.firstObject stringByAppendingPathComponent:fileName];
    return file;
}



- (void)requestForMoreMediaOfType:(AVMediaType)mediaType didWriteOnCompletionBlock:(void (^) (AVMediaType mediaType, CMSampleBufferRef sampleBuffer))finished {
    __weak_object__(self);
    [self startWriter];

    void (^appendPixelBufferBlock)
    (AVMediaType mType, CMSampleBufferRef sampleBuffer) = ^(AVMediaType mType, CMSampleBufferRef sampleBuffer) {
        __strong_object__(weakself);
        CMTime pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
        if (![strongForweakself getWriterInputForMediaType:mType].readyForMoreMediaData) {
            NSLog(@"drop a %@ frame, timestamp = %f", (mediaType == AVMediaTypeAudio) ? @"audio" : @"video", CMTimeGetSeconds(pts));
            // NSDate *maxDate = [NSDate dateWithTimeIntervalSinceNow:0.1];
            // [[NSRunLoop currentRunLoop] runUntilDate:maxDate];
            return;
        }
        if (mediaType == AVMediaTypeVideo) {
            CVImageBufferRef imageBuffer = CVBufferRetain(CMSampleBufferGetImageBuffer(sampleBuffer));
            CVPixelBufferLockBaseAddress(imageBuffer, 0);
            if ([strongForweakself.inputPixelBufferAdaptor appendPixelBuffer:imageBuffer withPresentationTime:pts]) {
                CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
                CVBufferRelease(imageBuffer);
            } else {
                NSLog(@"ImagePixelbuffer append failed, timestamp is = %f", CMTimeGetSeconds(pts));
            }
        } else {
            [self.audioAssetWriterInput appendSampleBuffer:sampleBuffer];
        }
        CFRelease(sampleBuffer);
    };
    
    [[self getWriterInputForMediaType:mediaType] requestMediaDataWhenReadyOnQueue:[self writeQueueWithMediaType:mediaType]
                                                                       usingBlock:^{
        __strong_object__(weakself);
        while ([[strongForweakself getWriterInputForMediaType:mediaType] isReadyForMoreMediaData]) {
            if (!strongForweakself.writeReadyOnBlock) {
                strongForweakself.writeReadyOnBlock = appendPixelBufferBlock;
            }
        }
        strongForweakself.writeReadyOnBlock = NULL;
    }];
    
}


- (BOOL)writerInputSampleBuffer:(CMSampleBufferRef)sampleBuffer mediaType:(AVMediaType)mediaType {
    if (sampleBuffer && self.assetWriter.status == AVAssetWriterStatusWriting) {
        if (self.writeReadyOnBlock) {
            self.writeReadyOnBlock(mediaType, sampleBuffer);
        }
    } else {
        if (self.assetWriter.status != AVAssetWriterStatusUnknown) {
            [[self getWriterInputForMediaType:mediaType] markAsFinished];
        }
        return NO;
    }
    return YES;
}


#pragma mark    -   observer, kvo

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if ([keyPath isEqualToString:kObserverWriterOutputStatus]) {
        switch (self.assetWriter.status) {
            case AVAssetWriterStatusWriting:
                NSLog(@"writer video of status is writing ...");
                break;
                
            case AVAssetWriterStatusCompleted:
                NSLog(@"writer video of status is completed ...");
                [self.assetWriter endSessionAtSourceTime:kCMTimeZero];
                [self.assetWriter finishWritingWithCompletionHandler:^{
                    NSLog(@"writer end ...");
                }];
                [self removeObserver:self forKeyPath:@"assetReader.status"];
                break;
                
            case AVAssetWriterStatusFailed:
                NSLog(@"writer video of status is failed ...  %@", self.assetWriter.error);
                break;
                
            case AVAssetReaderStatusCancelled:
                NSLog(@"writer video of status is cancelled ...");
                break;
                
            default:
                break;
        }
    }
}

@end