//
//  DFLocationStore.h
//  Strand
//
//  Created by Henry Bridge on 6/17/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

@interface DFLocationStore : NSObject

+ (void)StoreLastLocation:(CLLocation *)location;
+ (CLLocation *)LoadLastLocation;

@end
