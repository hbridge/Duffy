//
//  NSDateFormatter+DFPhotoDateFormatters.h
//  Duffy
//
//  Created by Henry Bridge on 4/30/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSDateFormatter (DFPhotoDateFormatters)

+ (NSDateFormatter *)EXIFDateFormatter;

+ (NSDateFormatter *)DjangoDateFormatter;
+ (NSString *)relativeTimeStringSinceDate:(NSDate *)date abbreviate:(BOOL)abbreviate;
+ (NSDateFormatter *)HumanDateFormatter;


@end
