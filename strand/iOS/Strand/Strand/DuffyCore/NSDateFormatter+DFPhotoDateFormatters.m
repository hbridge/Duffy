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

+ (NSDateFormatter *)HumanDateFormatter
{
  dispatch_semaphore_wait(DateFormmaterCreateSemaphore, DISPATCH_TIME_FOREVER);
  static NSDateFormatter *humanDateFormatter = nil;
  if (!humanDateFormatter) {
    humanDateFormatter = [[NSDateFormatter alloc] init];
    [humanDateFormatter setDateStyle:NSDateFormatterMediumStyle];
    [humanDateFormatter setTimeStyle:NSDateFormatterNoStyle];
  }
  dispatch_semaphore_signal(DateFormmaterCreateSemaphore);
  
  return humanDateFormatter;

}

+ (NSString *)relativeTimeStringSinceDate:(NSDate *)date
{
  NSTimeInterval timeSinceDate = [[NSDate date] timeIntervalSinceDate:date];
  if (timeSinceDate < 60.0) return @"1m";
  if (timeSinceDate < 60.0 * 60) return [NSString stringWithFormat:@"%dm", (int)timeSinceDate/60];
  if (timeSinceDate < 60.0 * 60 * 24) return [NSString stringWithFormat:@"%dh", (int)timeSinceDate/60/60];
  return [NSString stringWithFormat:@"%dd", (int)timeSinceDate/60/60/24];
}

@end
