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

- (BOOL)isNotEmpty
{
  return ![self isEqualToString:@""];
}

+ (NSString *)stringWithCommaSeparatedStrings:(NSArray *)strings
{
  NSMutableString *result = [[NSMutableString alloc] init];
  for (NSUInteger i = 0; i < strings.count; i++) {
    [result appendString:strings[i]];
    if (i < strings.count - 1) {
      [result appendString:@", "];
    }
  }
  return result;
}

@end
