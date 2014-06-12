//
//  ALAsset+DFExtensions.m
//  Duffy
//
//  Created by Henry Bridge on 5/12/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "ALAsset+DFExtensions.h"
#import "NSDateFormatter+DFPhotoDateFormatters.h"

@implementation ALAsset (DFExtensions)

- (NSDate *)creationDateForTimeZone:(NSTimeZone *)timezone
{
  if (self.defaultRepresentation.metadata) {
    NSDictionary *metadata = self.defaultRepresentation.metadata;
    NSDictionary *exifDict = metadata[@"{Exif}"];
    if (exifDict) {
      if (exifDict[@"DateTimeOriginal"]){
        NSDateFormatter *exifFormatter = [NSDateFormatter EXIFDateFormatter];
        exifFormatter.timeZone = timezone;
        NSDate *date = [exifFormatter dateFromString:exifDict[@"DateTimeOriginal"]];
        return date;
      }
    }
  }
  
  return [self valueForProperty:ALAssetPropertyDate];
}

- (NSDate *)creationDate
{
  return [self creationDateForTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
}


@end
