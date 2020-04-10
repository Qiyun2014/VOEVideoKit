//
//  ViewController.m
//  VideoReverse
//
//  Created by qiyun on 2020/4/7.
//  Copyright © 2020 qiyun. All rights reserved.
//

#import "ViewController.h"
#import "VOEVideoReader.h"
#import "VOEVideWriter.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    NSString *file = [[NSBundle mainBundle] pathForResource:@"IMG_0007" ofType:@"mp4"];
    VOEVideo *videoHandle = [VOEVideo videoForURL:[NSURL fileURLWithPath:file]];
    VOEVideoReader *videoReader = [[VOEVideoReader alloc] initWithVideo:videoHandle];
    
    
    NSString *outputFile = [VOEVideWriter createTempFileWithFormat:@"mp4"];
    VOEVideWriter *writerHandle = [[VOEVideWriter alloc] initWithURL:[NSURL fileURLWithPath:outputFile]];
    writerHandle.naturesize = videoReader.getVideoHandle.naturalSize;
    
    
    [videoReader readerMediaWithPrepareBlock:^{
        [writerHandle startWriter];
    } completionHandler:^(CMSampleBufferRef  _Nonnull sampleBuffer, AVMediaType  _Nonnull mediaType) {
        [writerHandle writerInputSampleBuffer:sampleBuffer mediaType:mediaType];
    }];
    
    

}


@end
