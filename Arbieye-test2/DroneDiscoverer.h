//
//  DroneDiscoverer.h
//  Arbieye-test2
//
//  Created by morishi on 2016/12/10.
//  Copyright © 2016年 morishi. All rights reserved.
//

#import <Foundation/Foundation.h>

@class DroneDiscoverer;

@protocol DroneDiscovererDelegate<NSObject>

/**
 * Called when the device found list is updated
 * Called on the main thread
 * @param droneDiscoverer the drone discoverer concerned
 * @param dronesList the list of found ARService
 */
- (void)droneDiscoverer:(DroneDiscoverer*)droneDiscoverer didUpdateDronesList:(NSArray*)dronesList;

@end

@interface DroneDiscoverer : NSObject

@property (nonatomic, weak) id<DroneDiscovererDelegate> delegate;

- (void)startDiscovering;
- (void)stopDiscovering;

@end
