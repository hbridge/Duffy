//
//  NSString+DFHelpers.m
//  Strand
//
//  Created by Henry Bridge on 7/8/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "NSString+DFHelpers.h"

@implementation NSString (DFHelpers)

- (NSRange)fullRange
{
  return (NSRange){0, self.length};
}

@end
