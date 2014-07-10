//
//  DFBackgroundLocationManager.h
//  Strand
//
//  Created by Henry Bridge on 7/2/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

@interface DFBackgroundLocationManager : NSObject <CLLocationManagerDelegate>

+ (DFBackgroundLocationManager *)sharedBackgroundLocationManager;
- (void)startUpdatingOnSignificantLocationChange;
- (CLLocation *)lastLocation;

@end
