//
//  NSString+DFHelpers.h
//  Strand
//
//  Created by Henry Bridge on 7/8/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (DFHelpers)

- (NSRange)fullRange;
- (BOOL)isNotEmpty;
+ (NSString *)stringWithCommaSeparatedStrings:(NSArray *)strings;

@end
