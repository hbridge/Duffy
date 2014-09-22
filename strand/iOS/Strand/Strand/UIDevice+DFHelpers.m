//
//  UIDevice+DFHelpers.m
//  Strand
//
//  Created by Henry Bridge on 9/22/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "UIDevice+DFHelpers.h"

@implementation UIDevice (DFHelpers)

+ (NSInteger)majorVersionNumber
{
  NSArray *vComp = [[UIDevice currentDevice].systemVersion componentsSeparatedByString:@"."];
  return [(NSString *)vComp[0] integerValue];
}

@end
