//
//  NSAttributedString+DFHelpers.h
//  Strand
//
//  Created by Henry Bridge on 10/22/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSAttributedString (DFHelpers)

+ (NSAttributedString *)attributedStringWithBlackText:(NSString *)blackText
                                             grayText:(NSString *)grayText
                                             grayFont:(UIFont *)grayFont;

@end
