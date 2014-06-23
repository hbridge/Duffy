//
//  DFPeanutLocationAdapter.h
//  Strand
//
//  Created by Henry Bridge on 6/23/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DFNetworkAdapter.h"
#import <CoreLocation/CoreLocation.h>

typedef void (^DFUpdateLocationResponseBlock)(BOOL success);

@interface DFPeanutLocationAdapter : NSObject <DFNetworkAdapter>

- (void)updateLocation:(CLLocation *)location
         withTimestamp:(NSDate *)date
       completionBlock:(DFUpdateLocationResponseBlock)completionBlock;

@end
