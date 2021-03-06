//
//  SDCardModule.m
//  Arbieye-test2
//
//  Created by morishi on 2016/12/10.
//  Copyright © 2016年 morishi. All rights reserved.
//

#import "SDCardModule.h"
#import <libARMedia/ARMedia.h>
#import <libARDataTransfer/ARDataTransfer.h>
#import <libARMedia/ARMedia.h>
#import <libARMedia/ARMEDIA_Object.h>

#define DRONE_MEDIA_FOLDER @"internal_000"
#define MOBILE_MEDIA_FOLDER @"ARSDKMedias"

@interface SDCardModule ()

@property (nonatomic, assign) ARDATATRANSFER_Manager_t *manager;
@property (nonatomic, assign) BOOL isCurrentlyDownloading;
@property (nonatomic, assign) BOOL isCancelled;

@property (nonatomic, assign) int lastProgressSent;

@property (nonatomic, assign) NSUInteger nbMaxDownload;
@property (nonatomic, assign) int currentDownloadIndex; // from 1 to nbMaxDownload
@end

@implementation SDCardModule

- (id)initWithFtpListManager:(ARUTILS_Manager_t*)ftpListManager andFtpQueueManager:(ARUTILS_Manager_t*)ftpQueueManager {
    self = [super init];
    if (self) {
        eARDATATRANSFER_ERROR result = ARDATATRANSFER_OK;
        _manager = ARDATATRANSFER_Manager_New(&result);
        
        if (result == ARDATATRANSFER_OK) {
            NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
            NSString *documentDir = [paths lastObject];
            NSString *mediaDirectory = [documentDir stringByAppendingPathComponent:MOBILE_MEDIA_FOLDER];
            
            result = ARDATATRANSFER_MediasDownloader_New(_manager, ftpListManager, ftpQueueManager, [DRONE_MEDIA_FOLDER UTF8String], [mediaDirectory UTF8String]);
        }
        
        if (result != ARDATATRANSFER_OK) {
            NSLog(@"Error while creating the media downloader: %s", ARDATATRANSFER_Error_ToString(result));
        }
    }
    return self;
}

- (void)getFlightMedias:(NSString*)runId {
    if (!_isCurrentlyDownloading) {
        _isCurrentlyDownloading = YES;
        [self performSelectorInBackground:@selector(getFlightMediasInBg:) withObject:runId];
    }
}

- (void)getTodaysFlightMedias {
    if (!_isCurrentlyDownloading) {
        _isCurrentlyDownloading = YES;
        [self performSelectorInBackground:@selector(getTodaysFlightMediasInBg) withObject:nil];
    }
}

- (void)cancelGetMedias {
    _isCancelled = YES;
    ARDATATRANSFER_MediasDownloader_CancelQueueThread(_manager);
}

- (void)getFlightMediasInBg:(NSString*)runId {
    NSArray *mediasList = [self getMediasList];
    
    NSArray *matchingMedias = nil;
    if (mediasList && !_isCancelled) {
        matchingMedias = [self getMatchingMediasFromList:mediasList withRunId:runId];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [_delegate sdcardModule:self didFoundMatchingMedias:[matchingMedias count]];
    });
    
    if (!_isCancelled && [matchingMedias count] != 0) {
        [self downloadMedias:matchingMedias];
    }
    
    _isCurrentlyDownloading = NO;
    _isCancelled = NO;
}

- (void)getTodaysFlightMediasInBg {
    NSArray *mediasList = [self getMediasList];
    
    NSArray *matchingMedias = nil;
    if (mediasList && !_isCancelled) {
        NSDate *today = [NSDate date];
        matchingMedias = [self getMatchingMediasFromList:mediasList withDate:today];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [_delegate sdcardModule:self didFoundMatchingMedias:[matchingMedias count]];
    });
    
    if (!_isCancelled && [matchingMedias count] != 0) {
        [self downloadMedias:matchingMedias];
    }
    
    _isCurrentlyDownloading = NO;
    _isCancelled = NO;
}

- (NSArray*)getMediasList {
    NSMutableArray *mediasList = nil;
    eARDATATRANSFER_ERROR result = ARDATATRANSFER_OK;
    int mediasListCount = 0;
    ARDATATRANSFER_Media_t *currentMedia = NULL;
    
    // get the number of files available to download
    mediasListCount = ARDATATRANSFER_MediasDownloader_GetAvailableMediasSync(_manager,0,&result);
    if (result == ARDATATRANSFER_OK) {
        mediasList = [NSMutableArray array];
        // for each file, get the info about it
        for (int i = 0 ; i < mediasListCount && !_isCancelled; i++) {
            currentMedia = ARDATATRANSFER_MediasDownloader_GetAvailableMediaAtIndex(_manager,i,&result);
            ARMediaObject *mediaObject = [[ARMediaObject alloc] init];
            [mediaObject updateDataTransferMedia:currentMedia withIndex:(unsigned long)i];
            
            if (mediaObject != nil) {
                [mediasList addObject:mediaObject];
            }
        }
    }
    return mediasList;
}

- (NSArray*)getMatchingMediasFromList:(NSArray*)mediasList withRunId:(NSString*)runId {
    NSMutableArray *matchingMedias = [[NSMutableArray alloc] init];
    
    for (ARMediaObject *mediaObject in mediasList) {
        if ([mediaObject.name rangeOfString:runId].location != NSNotFound) {
            [matchingMedias addObject:mediaObject];
        }
        
        // exit if the download is cancelled
        if (_isCancelled) {
            break;
        }
    }
    
    return matchingMedias;
}

- (NSArray*)getMatchingMediasFromList:(NSArray*)mediasList withDate:(NSDate*)date {
    NSMutableArray *matchingMedias = [[NSMutableArray alloc] init];
    
    NSDateFormatter *stringToDateFormatter = [[NSDateFormatter alloc] init];
    [stringToDateFormatter setDateFormat:@"yyyy-MM-dd'T'HHmmssZZZZ"];
    
    NSDateFormatter *dateToStrFormatter = [[NSDateFormatter alloc] init];
    [dateToStrFormatter setDateFormat:@"yyyy-MM-dd"];
    
    NSString *dateStr = [dateToStrFormatter stringFromDate:date];
    
    // for each media, add it to the matching list only if its date matches with the given date
    for (ARMediaObject *mediaObject in mediasList) {
        NSDate *mediaDate = [stringToDateFormatter dateFromString:[mediaObject date]];
        NSString *mediaDateStr = [dateToStrFormatter stringFromDate:mediaDate];
        if ([mediaDateStr isEqualToString:dateStr]) {
            [matchingMedias addObject:mediaObject];
        }
        
        // exit if the download is cancelled
        if (_isCancelled) {
            break;
        }
    }
    
    return matchingMedias;
}

- (void)downloadMedias:(NSArray*)matchingMedias {
    eARDATATRANSFER_ERROR result = ARDATATRANSFER_OK;
    
    _lastProgressSent = -1;
    _nbMaxDownload = [matchingMedias count];
    _currentDownloadIndex = 1;
    
    // add all medias to the download queue
    for (ARMediaObject* mediaObject in matchingMedias) {
        NSInteger index = mediaObject.index;
        
        if (index != NSNotFound) {
            ARDATATRANSFER_Media_t * media = ARDATATRANSFER_MediasDownloader_GetAvailableMediaAtIndex(_manager, (int)index, &result);
            if (result == ARDATATRANSFER_OK) {
                result = ARDATATRANSFER_MediasDownloader_AddMediaToQueue(_manager, media, medias_downloader_progress_callback, (__bridge void *)(self), medias_downloader_completion_callback,(__bridge void*)self);
            }
        }
    }
    if (result == ARDATATRANSFER_OK) {
        // start the queue (=> start the download)
        ARDATATRANSFER_MediasDownloader_QueueThreadRun(_manager);
    }
}

#pragma mark C static function
void medias_downloader_progress_callback(void* arg, ARDATATRANSFER_Media_t *media, float percent) {
    SDCardModule *sdCardModule = (__bridge SDCardModule*)arg;
    int progressAsInt = floor(percent);
    if (sdCardModule.lastProgressSent != progressAsInt) {
        sdCardModule.lastProgressSent = progressAsInt;
        NSString *mediaName = [NSString stringWithUTF8String:media->name];
        dispatch_async(dispatch_get_main_queue(), ^{
            [sdCardModule.delegate sdcardModule:sdCardModule media:mediaName downloadDidProgress:percent];
        });
    }
    
}

void medias_downloader_completion_callback(void* arg, ARDATATRANSFER_Media_t *media, eARDATATRANSFER_ERROR error) {
    SDCardModule *sdCardModule = (__bridge SDCardModule*)arg;
    NSString *mediaName = [NSString stringWithUTF8String:media->name];
    dispatch_async(dispatch_get_main_queue(), ^{
        [sdCardModule.delegate sdcardModule:sdCardModule mediaDownloadDidFinish:mediaName];
    });
    
    // when all download are finished, stop the download runnable
    // in order to get out of the downloadMedias function
    sdCardModule.currentDownloadIndex++;
    if (sdCardModule.currentDownloadIndex > sdCardModule.nbMaxDownload) {
        ARDATATRANSFER_MediasDownloader_CancelQueueThread(sdCardModule.manager);
    }
}

@end
