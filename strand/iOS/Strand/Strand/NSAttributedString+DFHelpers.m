//
//  NSAttributedString+DFHelpers.m
//  Strand
//
//  Created by Henry Bridge on 10/22/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "NSAttributedString+DFHelpers.h"

@implementation NSAttributedString (DFHelpers)

+ (NSAttributedString *)attributedStringWithBlackText:(NSString *)blackText
                                             grayText:(NSString *)grayText
                                             grayFont:(UIFont *)grayFont
{
  NSMutableAttributedString *result = [[NSMutableAttributedString alloc] initWithString:blackText];
  if ([grayText isNotEmpty]) {
    NSAttributedString *grayAttributedString = [[NSAttributedString alloc]
                                                initWithString:grayText
                                                attributes:@{
                                                             NSForegroundColorAttributeName : [UIColor lightGrayColor],
                                                             NSFontAttributeName : grayFont
                                                             }];
    [result appendAttributedString:grayAttributedString];
  }
  
  return result;
}

@end
