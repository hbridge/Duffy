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

typedef void (^DFLocationManagerAuthPromptHandler)(CLAuthorizationStatus resultStatus);

+ (DFBackgroundLocationManager *)sharedManager;
- (void)startUpdatingOnSignificantLocationChange;
- (CLLocation *)lastLocation;
- (void)backgroundUpdateWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler;
- (BOOL)canPromptForAuthorization;
- (void)promptForAuthorization:(DFLocationManagerAuthPromptHandler)handler;
- (BOOL)isPermssionGranted;

@property (nonatomic, copy) DFLocationManagerAuthPromptHandler authPromptHandler;

@end
