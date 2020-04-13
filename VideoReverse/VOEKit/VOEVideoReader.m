//
//  VOEVideoReader.m
//  VideoReverse
//
//  Created by qiyun on 2020/4/7.
//  Copyright © 2020 qiyun. All rights reserved.
//

#import "VOEVideoReader.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

const void *kAssociatePropertyAssetReader = "com.videoReader.asset.objc";
const void *kAssociatePropertyAssetVideoReaderOutput = "com.videoReader.assetReader.output.objc";
const void *kAssociatePropertyAssetAudioReaderOutput = "com.audioReader.assetReader.output.objc";
NSString *kObserverReaderOutputStatus = @"assetReader.status";


typedef
void (^VOEDecodeCallback) (CMSampleBufferRef sampleBuffer, AVMediaType mediaType);


@interface VOEVideoReader () <AVPlayerItemOutputPullDelegate>

// Apple system of player
@property (strong, nonatomic) AVPlayer *mPlayer;

// Class representing a timer bound to the display vsync.
@property (strong, nonatomic) CADisplayLink *displayLink;

// A concrete subclass of AVPlayerItemOutput that vends video images as CVPixelBuffers.
@property (strong, nonatomic) AVPlayerItemVideoOutput *videoOutput;

// Application input background, or is atcive
@property (assign, nonatomic) BOOL isBackground;

// VOE video
@property (strong, nonatomic) VOEVideo  *mVideo;

// Decode notify
@property (copy, nonatomic) VOEDecodeCallback decodeCallback;

@end

@implementation VOEVideoReader


#pragma mark    -   life cycle


- (id)initWithVideo:(VOEVideo *)video {

    if (self = [super init]) {
        // Setup CADisplayLink which will callback displayPixelBuffer: at every vsync.
        self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkCallback:)];
        [self.displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
        [self.displayLink setPaused:YES];
        
        self.mVideo = video;
    }
    return self;
}


- (void)dealloc {
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
}


#pragma mark    -   set/get method


- (VOEVideo *)getVideoHandle {
    return self.mVideo;
}


- (AVPlayerItemVideoOutput *)videoOutput {
    if (!_videoOutput) {
        NSDictionary *pixBuffAttributes = @{(id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)};
        _videoOutput = [[AVPlayerItemVideoOutput alloc] initWithPixelBufferAttributes:pixBuffAttributes];
        // Sets the receiver's delegate and a dispatch queue on which the delegate will be called.
        [_videoOutput setDelegate:self queue:dispatch_queue_create("voe.output.pixelbuffer", DISPATCH_QUEUE_SERIAL)];
        // Message this method before you suspend your use of a CVDisplayLink or CADisplayLink
        [_videoOutput requestNotificationOfMediaDataChangeWithAdvanceInterval:0.03];
    }
    return _videoOutput;
}


#pragma mark    -   public method


- (BOOL)readerMediaWithPrepareBlock:(void (^) (void))prepareBlock completionHandler:(void (^) (CMSampleBufferRef sampleBuffer, AVMediaType mediaType))handler {
    if (handler) {
        self.decodeCallback = handler;
        return [self startDecompressionVideoWithPrepareBlock:prepareBlock];
    }
    return false;
}


#pragma mark    -   private method


- (void)applicationStatusOfUserNotification {
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willResignActive) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
}


// Application did become active
- (void)didBecomeActive{
    self.isBackground = NO;
    [self.displayLink setPaused:NO];
}


// Application will input background
- (void)willResignActive{
    self.isBackground = YES;
    [self.displayLink setPaused:YES];
}



- (void)preparePlayback {
    
    __weak_object__(self);
    [[[self.mPlayer currentItem] outputs] enumerateObjectsUsingBlock:^(AVPlayerItemOutput * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        __strong_object__(weakself);
        [[strongForweakself.mPlayer currentItem] removeOutput:obj];
    }];
    
    AVPlayerItem *playerItem = [AVPlayerItem playerItemWithURL:self.mVideo.url];
    AVAsset *mAsset = playerItem.asset;
    [mAsset loadValuesAsynchronouslyForKeys:@[@"tracks"] completionHandler:^{
        if ([mAsset statusOfValueForKey:@"tracks" error:nil] ==  AVKeyValueStatusLoaded) {
            NSArray *videoTracks = [mAsset tracksWithMediaType:AVMediaTypeVideo];
            if ([videoTracks count] > 0) {
                AVAssetTrack *videoTrack = videoTracks.firstObject;
                [videoTrack loadValuesAsynchronouslyForKeys:@[@"preferredTransform"] completionHandler:^{
                    if ([videoTrack statusOfValueForKey:@"preferredTransform" error:nil] == AVKeyValueStatusLoaded) {
                        // CGAffineTransform preferredTransform = [videoTrack preferredTransform];
                        dispatch_async(dispatch_get_main_queue(), ^{
                            __strong_object__(weakself);
                            if (![playerItem.outputs containsObject:strongForweakself.videoOutput]) {
                                [playerItem addOutput:strongForweakself.videoOutput];
                            }
                            [strongForweakself.mPlayer replaceCurrentItemWithPlayerItem:playerItem];
                            [strongForweakself.videoOutput requestNotificationOfMediaDataChangeWithAdvanceInterval:0.03];
                            [strongForweakself.mPlayer play];
                        });
                    }
                }];
            }
        }
    }];
}


- (void)displayLinkCallback:(CADisplayLink *)displayLink {
    
    /*
     The callback gets called once every Vsync.
     Using the display link's timestamp and duration we can compute the next time the screen will be refreshed, and copy the pixel buffer for that time
     This pixel buffer can then be processed and later rendered on screen.
     */
    CMTime outputItemTime = kCMTimeInvalid;
    
    // Calculate the nextVsync time which is when the screen will be refreshed next.
    CFTimeInterval nextVSync = ([displayLink timestamp] + [displayLink duration]);
    
    outputItemTime = [[self videoOutput] itemTimeForHostTime:nextVSync];
    
    if ([[self videoOutput] hasNewPixelBufferForItemTime:outputItemTime] && !_isBackground) {
        CVPixelBufferRef pixelBuffer = NULL;
        pixelBuffer = [[self videoOutput] copyPixelBufferForItemTime:outputItemTime itemTimeForDisplay:NULL];
        
        
        if (pixelBuffer != NULL) {
            CFRelease(pixelBuffer);
        }
    } else {
        [self preparePlayback];
    }
}


#pragma mark    -   AVPlayerItemOutputPullDelegate

 /*!
    @method            outputMediaDataWillChange:
    @abstract        A method invoked once, prior to a new sample, if the AVPlayerItemOutput sender was previously messaged requestNotificationOfMediaDataChangeWithAdvanceInterval:.
    @discussion
        This method is invoked once after the sender is messaged requestNotificationOfMediaDataChangeWithAdvanceInterval:.
  */

- (void)outputMediaDataWillChange:(AVPlayerItemOutput *)sender API_AVAILABLE(macos(10.8), ios(6.0), tvos(9.0), watchos(1.0)) {
 
    NSLog(@"output media data will change ...");
    
    // Restart display link.
    [[self displayLink] setPaused:NO];
}


 /*!
    @method            outputSequenceWasFlushed:
    @abstract        A method invoked when the output is commencing a new sequence.
    @discussion
        This method is invoked after any seeking and change in playback direction. If you are maintaining any queued future samples, copied previously, you may want to discard these after receiving this message.
  */

- (void)outputSequenceWasFlushed:(AVPlayerItemOutput *)output API_AVAILABLE(macos(10.8), ios(6.0), tvos(9.0), watchos(1.0)) {
    
    NSLog(@"output sequence was flushed ...");
}


@end



@implementation
VOEVideoReader (VOEVideoAssetReader)


- (void)setAssetReader:(AVAssetReader *)assetReader {
    objc_setAssociatedObject([VOEVideoReader class], kAssociatePropertyAssetReader, assetReader, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}


- (AVAssetReader *)assetReader {
    return objc_getAssociatedObject([VOEVideoReader class], kAssociatePropertyAssetReader);
}


- (void)setVideoReaderOutput:(AVAssetReaderOutput *)videoReaderOutput {
    objc_setAssociatedObject([VOEVideoReader class], kAssociatePropertyAssetVideoReaderOutput, videoReaderOutput, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}


- (AVAssetReaderOutput *)videoReaderOutput {
    return objc_getAssociatedObject([VOEVideoReader class], kAssociatePropertyAssetVideoReaderOutput);
}


- (void)setAudioReaderOutput:(AVAssetReaderOutput *)audioReaderOutput {
    objc_setAssociatedObject([VOEVideoReader class], kAssociatePropertyAssetAudioReaderOutput, audioReaderOutput, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}


- (AVAssetReaderOutput *)audioReaderOutput {
    return objc_getAssociatedObject([VOEVideoReader class], kAssociatePropertyAssetAudioReaderOutput);
}


- (NSDictionary *)writeInputSettings {
    return @{AVVideoCodecKey : AVVideoCodecTypeH264,
             AVVideoWidthKey : @(self. mVideo.naturalSize.width),
             AVVideoHeightKey : @(self.mVideo.naturalSize.height),
             AVVideoCompressionPropertiesKey : @{AVVideoAverageBitRateKey : @(2000 * 1024)}
    };
}


- (NSDictionary *)outputSettingWithMediaType:(AVMediaType)mediaType {
    NSDictionary *auidoSetting = @{AVFormatIDKey                        : @(kAudioFormatLinearPCM),
                                   AVLinearPCMIsBigEndianKey            : @NO,
                                   AVLinearPCMIsFloatKey                : @YES,
                                   AVLinearPCMBitDepthKey               : @(32),
                                   // AVSampleRateConverterAudioQualityKey : @(AVAudioQualityHigh),     // Not support format is lpcm
                                   // AVEncoderBitRateKey                  : @(96 * 1024)               // Not support format is lpcm
    };
    return (mediaType == AVMediaTypeAudio) ? auidoSetting : @{(id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA)};
}


- (NSDictionary *)getAudioOutputSetting {
    return [self outputSettingWithMediaType:AVMediaTypeAudio];
}

- (NSDictionary *)getVideoOutputSetting {
    return [self outputSettingWithMediaType:AVMediaTypeVideo];
}

#pragma mark    -   public method

- (BOOL)startDecompressionVideoWithPrepareBlock:(void (^) (void))prepareBlock {
    
    // Preset asset reader
    if (![self mediaReaderOutputSetting]) {
        return false;
    }

    // Add reader observer, listen to the status is start and complete
    [self addObserver:self forKeyPath:kObserverReaderOutputStatus options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:NULL];
    // self.assetReader.timeRange = CMTimeRangeMake(CMTimeMake(200, 10), CMTimeMake(100, 100));
    int frameCount = 0;
    if ([self.assetReader startReading]) {
        // preset
        if (prepareBlock) {
            prepareBlock();
        } else {
            const dispatch_semaphore_t transcode = dispatch_semaphore_create(0);
            while (self.assetReader.status == AVAssetReaderStatusReading) {
                const CMSampleBufferRef videoSampleBuffer = self.videoReaderOutput.copyNextSampleBuffer;
                const CMSampleBufferRef audioSampleBuffer = self.audioReaderOutput.copyNextSampleBuffer;
                if (videoSampleBuffer || audioSampleBuffer) {
                    // Do something
                    if (videoSampleBuffer) {
                        NSLog(@"decode video sample buffer %d", frameCount ++);
                        // CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(videoSampleBuffer);
                        if (self.decodeCallback) {
                            self.decodeCallback(videoSampleBuffer, AVMediaTypeVideo);
                        }
                        CFRelease(videoSampleBuffer);
                    }
                    if (audioSampleBuffer) {
                        NSLog(@"decode audio sample buffer %d", frameCount ++);
                        if (self.decodeCallback) {
                            self.decodeCallback(audioSampleBuffer, AVMediaTypeVideo);
                        }
                        CFRelease(audioSampleBuffer);
                    }
                 } else {
                    dispatch_semaphore_signal(transcode);
                 }
            }
            NSLog(@"decode finished ... ");
            dispatch_semaphore_wait(transcode, DISPATCH_TIME_FOREVER);
        }
        return true;
    } else {
        NSLog(@"assetReader failed, status is = %ld, error = %@", (long)self.assetReader.status, self.assetReader.error);
    }
    return false;
}


#pragma mark    -   private method


- (BOOL)mediaReaderOutputSetting {
    // Not support repeat preset
    if (self.assetReader.status == AVAssetReaderStatusReading || self.assetReader.outputs.count > 0) {
        return true;
    }
    
    NSError *outError;
    self.assetReader = [AVAssetReader assetReaderWithAsset:self.mVideo.getAsset error:&outError];

    /**
     Always check that the asset reader returned to you is non-nil to ensure that the asset reader was initialized successfully.
     Otherwise, the error parameter (outError in the previous example) will contain the relevant error information.
     */
    if (outError) {
        NSLog(@"Asset reader failed, could not loading input the aseet. the error season is %@", outError);
        return false;
    }
    
    // Decode video to sample buffer
    if (self.mVideo.videoTrack) {
        self.videoReaderOutput = [[AVAssetReaderTrackOutput alloc] initWithTrack:self.mVideo.videoTrack outputSettings:[self outputSettingWithMediaType:AVMediaTypeVideo]];
        self.videoReaderOutput.alwaysCopiesSampleData = NO;
        if ([self.assetReader canAddOutput:self.videoReaderOutput]) {
            [self.assetReader addOutput:self.videoReaderOutput];
        }
    }
    // Decode audio to sample buffer
    if (self.mVideo.audioTrack) {
        self.audioReaderOutput = [[AVAssetReaderTrackOutput alloc] initWithTrack:self.mVideo.audioTrack outputSettings:[self outputSettingWithMediaType:AVMediaTypeAudio]];
        self.audioReaderOutput.alwaysCopiesSampleData = NO;
        if ([self.assetReader canAddOutput:self.audioReaderOutput]) {
            [self.assetReader addOutput:self.audioReaderOutput];
        }
    }
    return true;
}



- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    
    if ([keyPath isEqualToString:kObserverReaderOutputStatus]) {
        switch (self.assetReader.status) {
            case AVAssetReaderStatusReading:
                NSLog(@"decode video of status is reading ...");
                break;
                
            case AVAssetReaderStatusCompleted:
                NSLog(@"decode video of status is completed ...");
                [self removeObserver:self forKeyPath:@"assetReader.status"];
                break;
                
            case AVAssetReaderStatusFailed:
                NSLog(@"decode video of status is failed ...");
                break;
                
            case AVAssetReaderStatusCancelled:
                NSLog(@"decode video of status is cancelled ...");
                break;
                
            default:
                break;
        }
    }
}

@end
