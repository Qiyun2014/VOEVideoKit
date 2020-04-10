//
//  VOEVideo.m
//  VideoReverse
//
//  Created by qiyun on 2020/4/7.
//  Copyright © 2020 qiyun. All rights reserved.
//

#import "VOEVideo.h"
#import <UIKit/UIKit.h>
#import "VOEKit.h"

@interface VOEVideo ()

@property (strong, nonatomic) AVAsset       *mAsset;
@property (strong, nonatomic) AVURLAsset    *videoAsset;
@property (copy, nonatomic) NSString        *relativePath;

@end

@implementation VOEVideo

+ (id)videoForURL:(NSURL *)url {
    VOEVideo *video = [[VOEVideo alloc] initWithVideoForURL:url];
    return video;
}


- (id)initWithVideoForURL:(NSURL *)url {
    if (self = [super init]) {
        self.videoAsset = [AVURLAsset URLAssetWithURL:url options:@{AVURLAssetPreferPreciseDurationAndTimingKey : @true}];
        self.url = url;
        __weak_object__(self);
        [self.videoAsset loadValuesAsynchronouslyForKeys:[NSArray arrayWithObject:@"tracks"] completionHandler:^{
            __strong_object__(weakself);
            NSError *error = nil;
            AVKeyValueStatus tracksStatus = [strongForweakself.videoAsset statusOfValueForKey:@"tracks" error:&error];
            if (tracksStatus == AVKeyValueStatusLoaded) {
                strongForweakself.mAsset = strongForweakself.videoAsset;
            }
        }];
    }
    return self;
}


#pragma mark    -   get/set method


- (NSString *)format {
    return self.relativePath.lastPathComponent;
}


- (float)duration {
    return self.videoAsset.duration.value / self.videoAsset.duration.timescale;
}


- (CGSize)naturalSize {
    AVAssetTrack *videoAssetTrack = [self.videoAsset tracksWithMediaType:AVMediaTypeVideo].firstObject;
    return videoAssetTrack.naturalSize;
}


- (AVAsset *)getAsset {
    return self.mAsset;
}


- (AVAssetTrack *)getVideoTrack {
    return [self.asset tracksWithMediaType:AVMediaTypeVideo].firstObject;
}


- (AVAssetTrack *)getAudioTrack {
    return [self.asset tracksWithMediaType:AVMediaTypeAudio].firstObject;
}


#pragma mark    -   public method

- (void)thumbnailImageOfNumber:(NSInteger)number imageSize:(CGSize)size completionHandle:(void (^)(NSArray *))handle {
    
    NSMutableArray *coverImages = [[NSMutableArray alloc] init];
    AVAssetImageGenerator *imageGenerator = [AVAssetImageGenerator assetImageGeneratorWithAsset:self.videoAsset];
    imageGenerator.appliesPreferredTrackTransform = YES;
    imageGenerator.maximumSize = size;
    float timeScale = self.duration / number;
    
    // 计算视频中获取所需图片的间隔时间
    NSMutableArray *times = [[NSMutableArray alloc] init];
    for (Float64 i = 0; i < self.duration ; i += timeScale) // For 25 fps in 15 sec of Video
    {
        [times addObject:[NSValue valueWithCMTime:CMTimeMakeWithSeconds(i, 600)]];
    }
    
    // 按有序的间隔时间进行逐帧读取
    [imageGenerator generateCGImagesAsynchronouslyForTimes:times
                                         completionHandler:^(CMTime requestedTime,
                                                             CGImageRef  _Nullable image,
                                                             CMTime actualTime,
                                                             AVAssetImageGeneratorResult result,
                                                             NSError * _Nullable error) {
        if (result == AVAssetImageGeneratorSucceeded) {
            [coverImages addObject:[UIImage imageWithCGImage:image]];
            if (coverImages.count == number && handle) {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    [imageGenerator cancelAllCGImageGeneration];
                });
                handle(coverImages);
            }
        }
        if (result == AVAssetImageGeneratorFailed) {
            
        }
        if (result == AVAssetImageGeneratorCancelled) {
            
        }
    }];
}


@end
