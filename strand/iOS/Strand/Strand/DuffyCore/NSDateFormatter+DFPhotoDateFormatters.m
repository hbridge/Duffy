//
//  NSDateFormatter+DFPhotoDateFormatters.m
//  Duffy
//
//  Created by Henry Bridge on 4/30/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "NSDateFormatter+DFPhotoDateFormatters.h"

static dispatch_semaphore_t DateFormmaterCreateSemaphore;

@implementation NSDateFormatter (DFPhotoDateFormatters)

+(void)initialize
{
  DateFormmaterCreateSemaphore = dispatch_semaphore_create(1);
}


+ (NSDateFormatter *)EXIFDateFormatter
{
  dispatch_semaphore_wait(DateFormmaterCreateSemaphore, DISPATCH_TIME_FOREVER);
  static NSDateFormatter *exifFormatter = nil;
  if (!exifFormatter) {
    exifFormatter = [[NSDateFormatter alloc] init];
    exifFormatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
    [exifFormatter setDateFormat:@"yyyy:MM:dd HH:mm:ss"];
  }
  
  dispatch_semaphore_signal(DateFormmaterCreateSemaphore);
  return exifFormatter;
}



+ (NSDateFormatter *)DjangoDateFormatter
{
  dispatch_semaphore_wait(DateFormmaterCreateSemaphore, DISPATCH_TIME_FOREVER);
  static NSDateFormatter *djangoDateFormatter = nil;
  if (!djangoDateFormatter) {
    djangoDateFormatter = [[NSDateFormatter alloc] init];
    djangoDateFormatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
    [djangoDateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss'Z'"];
  }
  dispatch_semaphore_signal(DateFormmaterCreateSemaphore);
  
  return djangoDateFormatter;
}

@end
