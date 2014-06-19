//
//  DFStrandStore.m
//  Strand
//
//  Created by Henry Bridge on 6/19/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFStrandStore.h"
#import "DFStrandConstants.h"

@implementation DFStrandStore

+ (void) SaveUnseenPhotosCount:(int)count
{
  [[NSUserDefaults standardUserDefaults] setObject:@(count)
                                            forKey:DFStrandUnseenCountDefaultsKey];
  [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (int) UnseenPhotosCount
{
  NSNumber *totalUnseenCount = [[NSUserDefaults standardUserDefaults]
                                objectForKey:DFStrandUnseenCountDefaultsKey];
  return totalUnseenCount.intValue;
}


@end
