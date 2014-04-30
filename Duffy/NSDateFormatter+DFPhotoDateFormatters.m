//
//  NSDateFormatter+DFPhotoDateFormatters.m
//  Duffy
//
//  Created by Henry Bridge on 4/30/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "NSDateFormatter+DFPhotoDateFormatters.h"

@implementation NSDateFormatter (DFPhotoDateFormatters)

+ (NSDateFormatter *)EXIFDateFormatter
{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy:MM:dd HH:mm:ss"];
    return dateFormatter;
}

+ (NSDateFormatter *)DjangoDateFormatter
{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss'Z'"];
    return dateFormatter;
}



@end
