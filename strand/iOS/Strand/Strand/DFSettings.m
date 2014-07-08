//
//  DFSettings.m
//  Strand
//
//  Created by Henry Bridge on 7/8/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFSettings.h"
#import "DFAppInfo.h"

@implementation DFSettings

- (NSString *)version
{
  return [DFAppInfo appInfoString];
}

@end
