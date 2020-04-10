//
//  VOEFrame.h
//  VideoReverse
//
//  Created by qiyun on 2020/4/7.
//  Copyright © 2020 qiyun. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreMedia/CoreMedia.h>

NS_ASSUME_NONNULL_BEGIN

@interface VOEFrame : NSObject

@property (assign, nonatomic) CGSize resolution;
@property (strong, nonatomic) UIImage *image;
@property (assign, nonatomic) CMSampleBufferRef imageSampleBuffer;


@end

NS_ASSUME_NONNULL_END
