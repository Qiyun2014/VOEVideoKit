//
//  ViewController.m
//  VideoReverse
//
//  Created by qiyun on 2020/4/7.
//  Copyright © 2020 qiyun. All rights reserved.
//

#import "ViewController.h"
#import "VOEVideoReader.h"
#import "VOEVideoWriter.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    NSString *file = [[NSBundle mainBundle] pathForResource:@"IMG_0007" ofType:@"mp4"];
    VOEVideo *videoHandle = [VOEVideo videoForURL:[NSURL fileURLWithPath:file]];
    VOEVideoReader *videoReader = [[VOEVideoReader alloc] initWithVideo:videoHandle];
    
    
    NSString *outputFile = [VOEVideoWriter createTempFileWithFormat:@"mp4"];
    NSLog(@"file = %@", outputFile);
    VOEVideoWriter *writerHandle = [[VOEVideoWriter alloc] initWithURL:[NSURL fileURLWithPath:outputFile]];
    writerHandle.naturesize = videoReader.getVideoHandle.naturalSize;
    writerHandle.videoReader = videoReader;
    
    [videoReader startDecompressionVideoWithPrepareBlock:^{
        [writerHandle startWriter];
    }];

}


@end
