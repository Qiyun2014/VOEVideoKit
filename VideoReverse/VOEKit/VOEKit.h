//
//  VOEKit.h
//  VideoReverse
//
//  Created by qiyun on 2020/4/10.
//  Copyright © 2020 qiyun. All rights reserved.
//

#ifndef VOEKit_h
#define VOEKit_h

#define __weak_object__(obj) __weak typeof(obj) weak##obj = obj;
#define __strong_object__(obj) __strong typeof(obj) strongFor##obj = obj;


#import "VOEVideoReader.h"
#import "VOEVideWriter.h"
#import "VOEVideo.h"

// A picture size (kb) = width * height * bit / 8 / 1024



#endif /* VOEKit_h */
