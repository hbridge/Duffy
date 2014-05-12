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
  static NSDateFormatter *exifFormatter = nil;
  if (!exifFormatter) {
    exifFormatter = [[NSDateFormatter alloc] init];
    exifFormatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
    [exifFormatter setDateFormat:@"yyyy:MM:dd HH:mm:ss"];
  }
    return exifFormatter;
}

+ (NSDateFormatter *)DjangoDateFormatter
{
  static NSDateFormatter *djangoDateFormatter = nil;
  if (!djangoDateFormatter) {
    djangoDateFormatter = [[NSDateFormatter alloc] init];
    djangoDateFormatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
    [djangoDateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss'Z'"];
  }
  
  return djangoDateFormatter;
}

@end
