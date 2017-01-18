//
//  BebopVideoView.h
//  Arbieye-test2
//
//  Created by morishi on 2016/12/10.
//  Copyright © 2016年 morishi. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <libARController/ARController.h>

@interface BebopProcessedVideoView : UIView

- (BOOL)configureDecoder:(ARCONTROLLER_Stream_Codec_t)codec;
- (BOOL)displayFrame2:(ARCONTROLLER_Frame_t *)frame;

@end


