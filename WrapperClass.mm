//
//  WrapperClass.m
//  Arbieye-test2
//
//  Created by morishi on 2016/12/20.
//  Copyright © 2016年 morishi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WrapperClass.h"
#import <opencv2/objdetect/objdetect.hpp>
#include <opencv2/core/core.hpp>
#include <opencv2/highgui/highgui.hpp>
#include <opencv2/imgproc/imgproc.hpp>
#import "opencv2/opencv.hpp"

using namespace std;
using namespace cv;

@implementation WrapperClass

int currentStatus=10;


-(int)getCurrentStatus{
    NSLog(@"getCurrentStatusCalled");
    return currentStatus;
}

static BOOL _debug = NO;



-(void)setCurrentStatus:(CVImageBufferRef)imageBuffer{
    
    CVPixelBufferLockBaseAddress(imageBuffer, 0);

    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    IplImage *iplimage;
    if (baseAddress)
    {
        iplimage = cvCreateImageHeader(cvSize(width, height), IPL_DEPTH_8U, 4);
        iplimage->imageData = (char*)baseAddress;
    }
    
    IplImage *workingCopy = cvCreateImage(cvSize(height, width), IPL_DEPTH_8U, 4);
    
    cvReleaseImageHeader(&iplimage);
    
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    
    [self didCaptureIplImage:workingCopy];

}

- (void)didCaptureIplImage:(IplImage *)iplImage
{
    
    //ipl image is in BGR format, it needs to be converted to RGB for display in UIImageView
    IplImage *imgRGB = cvCreateImage(cvGetSize(iplImage), IPL_DEPTH_8U, 3);
    cvCvtColor(iplImage, imgRGB, CV_BGR2RGB);
    Mat matRGB = Mat(imgRGB);
    
    //ipl imaeg is also converted to HSV; hue is used to find certain color
    IplImage *imgHSV = cvCreateImage(cvGetSize(iplImage), 8, 3);
    cvCvtColor(iplImage, imgHSV, CV_BGR2HSV);
    
    IplImage *imgThreshed = cvCreateImage(cvGetSize(iplImage), 8, 1);
    
    cvReleaseImage(&iplImage);
    
    //filter all pixels in defined range, everything in range will be white, everything else
    //is going to be black
    
    cvInRangeS(imgHSV, cvScalar(230, 100, 100), cvScalar(255, 255, 255), imgThreshed);
    
    cvReleaseImage(&imgHSV);
    
    Mat matThreshed = Mat(imgThreshed);
    
    //smooths edges
    cv::GaussianBlur(matThreshed,
                     matThreshed,
                     cv::Size(9, 9),
                     2,
                     2);
    
    if (_debug)
    {
        cvReleaseImage(&imgRGB);
    }
    else
    {
        vector<Vec3f> circles;
        
        //get circles
        HoughCircles(matThreshed,
                     circles,
                     CV_HOUGH_GRADIENT,
                     2,
                     matThreshed.rows / 4,
                     150,
                     75,
                     10,
                     150);
        
        for (size_t i = 0; i < circles.size(); i++)
        {
            cout << "Circle position x = " << (int)circles[i][0] << ", y = " << (int)circles[i][1] << ", radius = " << (int)circles[i][2] << "\n";
            NSLog(@"Circles FOUND!!!!!!!!!!!!");
            
            
            cv::Point center(cvRound(circles[i][0]), cvRound(circles[i][1]));
            
            //int radius = cvRound(circles[i][2]);
            //circle(matRGB, center, 3, Scalar(0, 255, 0), -1, 8, 0);
            //circle(matRGB, center, radius, Scalar(0, 0, 255), 3, 8, 0);
        }
        
        //threshed image is not needed any more and needs to be released
        cvReleaseImage(&imgThreshed);
    }
}


@end
