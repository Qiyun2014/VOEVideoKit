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
    
    // 读取视频
    NSString *file = [[NSBundle mainBundle] pathForResource:@"IMG_0007" ofType:@"mp4"];
    VOEVideo *videoHandle = [VOEVideo videoForURL:[NSURL fileURLWithPath:file]];
    VOEVideoReader *videoReader = [[VOEVideoReader alloc] initWithVideo:videoHandle];
    
    // 创建新视频
    NSString *outputFile = [VOEVideoWriter createTempFileWithFormat:@"mp4"];
    NSLog(@"file = %@", outputFile);
    VOEVideoWriter *writerHandle = [[VOEVideoWriter alloc] initWithURL:[NSURL fileURLWithPath:outputFile]];
    writerHandle.naturesize = videoReader.getVideoHandle.naturalSize;
    writerHandle.videoReader = videoReader;
    
    // 解码每一帧视频
    [videoReader startDecompressionVideoWithPrepareBlock:^{
        // 编码每一帧视频到指定格式的文件，默认是quick time movie
        [writerHandle startWriter];
    }];

}


@end
