//
//  BebopVideoView.h
//  Arbieye-test2
//
//  Created by morishi on 2016/12/10.
//  Copyright © 2016年 morishi. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <libARController/ARController.h>

@interface BebopVideoView : UIView

- (BOOL)configureDecoder:(ARCONTROLLER_Stream_Codec_t)codec;
- (BOOL)displayFrame:(ARCONTROLLER_Frame_t *)frame;
- (int)throwCurrentStatus;


@end


