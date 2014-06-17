//
//  DFLocationStore.m
//  Strand
//
//  Created by Henry Bridge on 6/17/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFLocationStore.h"
#import "DFStrandConstants.h"

@implementation DFLocationStore

+ (void)StoreLastLocation:(CLLocation *)location
{
  NSData *data = [NSKeyedArchiver archivedDataWithRootObject:location];
  [[NSUserDefaults standardUserDefaults] setObject:data forKey:DFStrandLastKnownLocationDefaultsKey];
  [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (CLLocation *)LoadLastLocation
{
  NSData *data = [[NSUserDefaults standardUserDefaults] objectForKey:DFStrandLastKnownLocationDefaultsKey];
  if (!data) return nil;
  CLLocation *result = [NSKeyedUnarchiver unarchiveObjectWithData:data];
  return result;
}


@end
