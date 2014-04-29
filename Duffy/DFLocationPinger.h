//
//  DFLocationPinger.h
//  Duffy
//
//  Created by Henry Bridge on 4/28/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>


@interface DFLocationPinger : NSObject <CLLocationManagerDelegate>

@property (nonatomic, readonly) BOOL isKeepingAlive;

+ (DFLocationPinger *)sharedInstance;

- (BOOL)canMonitorLocation;
- (BOOL)canAskForLocationPermission;
- (void)askForLocationPermission;

- (void)addObjectRequestingKeepAlive:(id)object;
- (void)removeObjectRequestingKeepAlive:(id)object;

- (void)startPings;
- (void)stopPings;



@end
