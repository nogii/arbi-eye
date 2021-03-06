//
//  BebopVideoView.m
//  Arbieye-test2
//
//  Created by morishi on 2016/12/10.
//  Copyright © 2016年 morishi. All rights reserved.
//

#import "BebopVideoView.h"
#import <AVFoundation/AVFoundation.h>
#import <VideoToolbox/VideoToolbox.h>
#import "WrapperClass.h"
#import "AppDelegate.h"

#define app (AppDelegate *)[[UIApplication sharedApplication] delegate]

@interface BebopVideoView ()

@property (nonatomic, retain) AVSampleBufferDisplayLayer *videoLayer;
@property (nonatomic, assign) CMVideoFormatDescriptionRef formatDesc;
@property (nonatomic, retain) WrapperClass *wrapperClass;
@property (nonatomic, assign) int spsSize;
@property (nonatomic, assign) int ppsSize;
@property (nonatomic, assign) BOOL canDisplayVideo;
@property (nonatomic, assign) BOOL lastDecodeHasFailed;
@property (nonatomic, assign) VTDecompressionSessionRef decompressionSessionRef;

@end
@implementation BebopVideoView

int curSta=0;

- (id)init {
    self = [super init];
    if (self) {
        [self customInit];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self customInit];
    }
    
    return self;
}

- (id)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self customInit];
    }
    return self;
}

- (void)customInit {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(enteredBackground:) name:UIApplicationDidEnterBackgroundNotification object: nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(enterForeground:) name:UIApplicationWillEnterForegroundNotification object: nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(decodingDidFail:) name:AVSampleBufferDisplayLayerFailedToDecodeNotification object:nil];
    
    _canDisplayVideo = YES;
    
    // create CVSampleBufferDisplayLayer and add it to the view
    _videoLayer = [[AVSampleBufferDisplayLayer alloc] init];
    _videoLayer.frame = self.frame;
    _videoLayer.bounds = self.bounds;
    _videoLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    _videoLayer.backgroundColor = [[UIColor blackColor] CGColor];
    
    [[self layer] addSublayer:_videoLayer];
    [self setBackgroundColor:[UIColor blackColor]];
    
    _wrapperClass = [[WrapperClass alloc] init];
    NSLog(@"wrapper class made");
    }

-(void)dealloc {
    if (NULL != _formatDesc) {
        CFRelease(_formatDesc);
        _formatDesc = NULL;
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name: UIApplicationDidEnterBackgroundNotification object: nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name: UIApplicationWillEnterForegroundNotification object: nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name: AVSampleBufferDisplayLayerFailedToDecodeNotification object: nil];
}

- (void)layoutSubviews {
    _videoLayer.frame = self.bounds;
}

- (BOOL)configureDecoder:(ARCONTROLLER_Stream_Codec_t)codec {
    OSStatus osstatus;
    NSError *error = nil;
    BOOL success = NO;
    
    if (codec.type == ARCONTROLLER_STREAM_CODEC_TYPE_H264) {
        _lastDecodeHasFailed = NO;
        if (_canDisplayVideo) {
            
            uint8_t* props[] = {
                codec.parameters.h264parameters.spsBuffer+4,
                codec.parameters.h264parameters.ppsBuffer+4
            };
            
            size_t sizes[] = {
                codec.parameters.h264parameters.spsSize-4,
                codec.parameters.h264parameters.ppsSize-4
            };
            
            if (NULL != _formatDesc) {
                CFRelease(_formatDesc);
                _formatDesc = NULL;
            }

            osstatus = CMVideoFormatDescriptionCreateFromH264ParameterSets(NULL, 2,
                                                                           (const uint8_t *const*)props,
                                                                           sizes, 4, &_formatDesc);
            
            if (osstatus != kCMBlockBufferNoErr) {
                error = [NSError errorWithDomain:NSOSStatusErrorDomain
                                            code:osstatus
                                        userInfo:nil];
                
                NSLog(@"Error creating the format description = %@", [error description]);
                [self cleanFormatDesc];
            } else {
                //Video Decompression
                VTDecompressionOutputCallbackRecord callback;
                callback.decompressionOutputCallback = my_decompression_callback;
                callback.decompressionOutputRefCon = (__bridge void *)(self);
                VTDecompressionSessionCreate(NULL,
                                             _formatDesc,
                                             NULL,
                                             NULL,
                                             &callback,
                                             &_decompressionSessionRef);
                
                success = YES;
            }
        }
    }
    return success;
}

- (BOOL)displayFrame:(ARCONTROLLER_Frame_t *)frame
{
    BOOL success = !_lastDecodeHasFailed;

    if (success && _canDisplayVideo) {
        CMBlockBufferRef blockBufferRef = NULL;
        CMSampleTimingInfo timing = kCMTimingInfoInvalid;
        CMSampleBufferRef sampleBufferRef = NULL;
        
        OSStatus osstatus;
        NSError *error = nil;
        
        // on error, flush the video layer and wait for the next iFrame
        if (!_videoLayer || [_videoLayer status] == AVQueuedSampleBufferRenderingStatusFailed) {
            ARSAL_PRINT(ARSAL_PRINT_ERROR, "PilotingViewController", "Video layer status is failed : flush and wait for next iFrame");
            [self cleanFormatDesc];
            success = NO;
        }
        
        if (success) {
            osstatus  = CMBlockBufferCreateWithMemoryBlock(CFAllocatorGetDefault(), frame->data, frame->used, kCFAllocatorNull, NULL, 0, frame->used, 0, &blockBufferRef);
            if (osstatus != kCMBlockBufferNoErr) {
                error = [NSError errorWithDomain:NSOSStatusErrorDomain
                                            code:osstatus
                                        userInfo:nil];
                
                NSLog(@"Error creating the block buffer = %@", [error description]);
                success = NO;
            }
        }

        if (success) {
            const size_t sampleSize = frame->used;
            osstatus = CMSampleBufferCreate(kCFAllocatorDefault, blockBufferRef, true, NULL, NULL, _formatDesc, 1, 0, NULL, 1, &sampleSize, &sampleBufferRef);
            if (osstatus != noErr) {
                success = NO;
                error = [NSError errorWithDomain:NSOSStatusErrorDomain
                                            code:osstatus
                                        userInfo:nil];
                NSLog(@"Error creating the sample buffer = %@", [error description]);
            }
        }
        
        if (success) {
            // add the attachment which says that sample should be displayed immediately
            CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBufferRef, YES);
            CFMutableDictionaryRef dict = (CFMutableDictionaryRef)CFArrayGetValueAtIndex(attachments, 0);
            CFDictionarySetValue(dict, kCMSampleAttachmentKey_DisplayImmediately, kCFBooleanTrue);
        }

 

        if (success &&
            [_videoLayer status] != AVQueuedSampleBufferRenderingStatusFailed &&
            _videoLayer.isReadyForMoreMediaData)
        
        {
            
            osstatus = VTDecompressionSessionDecodeFrame(_decompressionSessionRef,
                                                         sampleBufferRef,
                                                         kVTDecodeFrame_1xRealTimePlayback,
                                                         NULL,
                                                         NULL);
            dispatch_sync(dispatch_get_main_queue(), ^{
                if (_canDisplayVideo)
                {

                    [_videoLayer enqueueSampleBuffer:sampleBufferRef];
                }
            });
        }
        // free memory
        if (NULL != sampleBufferRef) {
            CMSampleBufferInvalidate(sampleBufferRef);
            CFRelease(sampleBufferRef);
            sampleBufferRef = NULL;
        }
        
        if (NULL != blockBufferRef) {
            CFRelease(blockBufferRef);
            blockBufferRef = NULL;
        }
    }
    return success;
}


void my_decompression_callback(void *decompressionOutputRefCon,
                               void *sourceFrameRefCon,
                               OSStatus status,
                               VTDecodeInfoFlags infoFlags,
                               CVImageBufferRef imageBuffer,
                               CMTime presentationTimeStamp,
                               CMTime presentationDuration)
{
    //WrapperClass *wc = [[WrapperClass alloc] init];
    //[wc setCurrentStatus:imageBuffer];
    IplImage *iplimage = 0;
    if (imageBuffer) {
        CVPixelBufferLockBaseAddress(imageBuffer, 0);
        // get information of the image in the buffer
        uint8_t *bufferBaseAddress = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0);
        size_t bufferWidth = CVPixelBufferGetWidth(imageBuffer);
        size_t bufferHeight = CVPixelBufferGetHeight(imageBuffer);
        
        // create IplImage
        if (bufferBaseAddress) {
            iplimage = cvCreateImage(cvSize(bufferWidth, bufferHeight), IPL_DEPTH_8U, 4);
            iplimage->imageData = (char*)bufferBaseAddress;
        }
   
        
        //=============iplImage to UIImage ===================
        CGColorSpaceRef colorSpace;
        colorSpace = CGColorSpaceCreateDeviceRGB();
        NSData *data = [NSData dataWithBytes:iplimage->imageData length:iplimage->imageSize];
        
        CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
        
        
        CGImageRef imageRef = CGImageCreate(iplimage->width,
                                            iplimage->height,
                                            iplimage->depth,
                                            iplimage->depth * iplimage->nChannels,
                                            iplimage->widthStep,
                                            colorSpace,
                                            kCGImageAlphaNone|kCGBitmapByteOrderDefault,
                                            provider,
                                            NULL,
                                            false,
                                            kCGRenderingIntentDefault
                                            );
        
        
        UIImage *outputImage = [UIImage imageWithCGImage:imageRef];
        
        
        CGImageRelease(imageRef);
        CGDataProviderRelease(provider);
        CGColorSpaceRelease(colorSpace);
        
        // =====================================================
        
    }
}


-(int)throwCurrentStatus{
    return [_wrapperClass getCurrentStatus];
}

- (void)cleanFormatDesc {
    dispatch_sync(dispatch_get_main_queue(), ^{
        if (NULL != _formatDesc) {
            [_videoLayer flushAndRemoveImage];
            CFRelease(_formatDesc);
            _formatDesc = NULL;
        }
    });
}


#pragma mark - notifications
- (void)enteredBackground:(NSNotification*)notification {
    _canDisplayVideo = NO;
}

- (void)enterForeground:(NSNotification*)notification {
    _canDisplayVideo = YES;
}

- (void)decodingDidFail:(NSNotification*)notification {
    _lastDecodeHasFailed = YES;
}

@end
