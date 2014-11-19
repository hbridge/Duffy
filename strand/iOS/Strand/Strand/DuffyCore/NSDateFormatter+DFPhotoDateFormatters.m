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
    [exifFormatter setDateFormat:@"yyyy:MM:dd HH:mm:ssZZZ"];
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

+ (NSString *)relativeTimeStringSinceDate:(NSDate *)date abbreviate:(BOOL)abbreviate
{
  return [self relativeTimeStringSinceDate:date abbreviate:abbreviate inSentence:NO];
}

+ (NSString *)relativeTimeStringSinceDate:(NSDate *)date
                               abbreviate:(BOOL)abbreviate
                               inSentence:(BOOL)inSentence
{
  NSTimeInterval timeSinceDate = [[NSDate date] timeIntervalSinceDate:date];
  if (timeSinceDate < 0) timeSinceDate = 0;
  NSString *result;
  if (timeSinceDate < 60.0 * 60) {
    int minutes = ((int)timeSinceDate/60);
    if (abbreviate) {
      result = [NSString stringWithFormat:@"%dm", minutes];
    } else {
      result = [self pluralizedStringWithNumber:minutes unitString:@"minute"];
    }
  } else if (timeSinceDate < 60.0 * 60 * 24) {
    int hours = (int)timeSinceDate/60/60;
    if (abbreviate) {
      result = [NSString stringWithFormat:@"%dh", hours];
    } else {
      result = [self pluralizedStringWithNumber:hours unitString:@"hour"];
    }
  } else if (timeSinceDate < 60.0 * 60 * 24 * 7) {
    int days = (int)timeSinceDate/60/60/24;
    if (abbreviate) {
      result = [NSString stringWithFormat:@"%dd", days];
    } else {
      result = [self pluralizedStringWithNumber:days unitString:@"day"];
    }
  } else {
    if (inSentence) {
      result = [NSString stringWithFormat:@"on %@", [[self HumanDateFormatter] stringFromDate:date]];
    } else {
      result = [[self HumanDateFormatter] stringFromDate:date];
    }
  }
  
  return result;
}


+ (NSString *)pluralizedStringWithNumber:(int)number unitString:(NSString *)unitString
{
  return [NSString stringWithFormat:@"%d %@%@ ago",
          number,
          unitString,
          number > 1 || number == 0 ? @"s" : @""];
}

@end
