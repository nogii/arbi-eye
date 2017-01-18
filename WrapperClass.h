//
//  WrapperClass.h
//  Arbieye-test2
//
//  Created by morishi on 2016/12/20.
//  Copyright © 2016年 morishi. All rights reserved.
//


#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <VideoToolbox/VideoToolbox.h>
#import <opencv2/imgproc/imgproc_c.h>

@interface WrapperClass : NSObject{}
// <AVCaptureVideoDataOutputSampleBufferDelegate>

- (void)setCurrentStatus:(CVImageBufferRef)imageBuffer;
- (int)getCurrentStatus;

@end
