//
//  DFPeanutUserObject.m
//  Strand
//
//  Created by Henry Bridge on 7/7/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPeanutUserObject.h"
#import "RestKit/Restkit.h"
#import <CoreLocation/CoreLocation.h>
#import "UIImage+Resize.h"
#import "UIImage+RoundedCorner.h"

#import "DFContactDataManager.h"

@implementation DFPeanutUserObject

+ (RKObjectMapping *)objectMapping
{
  RKObjectMapping *objectMapping = [RKObjectMapping mappingForClass:[self class]];
  [objectMapping addAttributeMappingsFromArray:[self simpleAttributeKeys]];
  
  return objectMapping;
}

+ (NSArray *)simpleAttributeKeys
{
  return @[@"id",
           @"display_name",
           @"phone_number",
           @"phone_id",
           @"auth_token",
           @"device_token",
           @"last_location_point",
           @"last_location_accuracy",
           @"last_photo_timestamp",
           @"last_photo_update_timestamp",
           @"first_run_sync_timestamp",
           @"first_run_sync_count",
           @"invites_remaining",
           @"invites_sent",
           @"added",
           @"invited",
           ];
}

- (NSString *)description
{
  return [[self dictionaryWithValuesForKeys:[self.class simpleAttributeKeys]] description];
}

- (NSDictionary *)requestParameters
{
  return [self dictionaryWithValuesForKeys:[self.class simpleAttributeKeys]];
}

- (void)setLocation:(CLLocation *)location
{
  self.last_location_point = [NSString stringWithFormat:@"POINT (%f %f)",
                              location.coordinate.latitude,
                              location.coordinate.longitude];
  self.last_location_accuracy = @(location.horizontalAccuracy);
}

- (BOOL)isEqual:(id)object
{
  if (![[object class] isSubclassOfClass:self.class]) return NO;
  DFPeanutUserObject *otherUser = (DFPeanutUserObject *)object;
  if (self.id == otherUser.id) return YES;
  
  return NO;
}


- (NSString *)firstName
{
  return [[[self fullName] componentsSeparatedByString:@" "] firstObject];
}

- (NSString *)fullName
{
  NSString *localName = [[DFContactDataManager sharedManager] localNameFromPhoneNumber:self.phone_number];
  
  if (localName) {
    return localName;
  } else {
    return self.display_name;
  }
}

- (NSUInteger)hash
{
  return (NSUInteger)self.id;
}

- (UIImage *)thumbnail
{
  return [DFPeanutUserObject UIImageForThumbnailFromPhoneNumber:self.phone_number];
}

- (UIImage *)roundedThumbnailOfPointSize:(CGSize)size
{
  CGSize imageSize = CGSizeMake(size.width * [[UIScreen mainScreen] scale],
                                size.height * [[UIScreen mainScreen] scale]);
  UIImage *resizedImage = [[self thumbnail] resizedImage:imageSize
                         interpolationQuality:kCGInterpolationDefault];
  UIImage *roundedImage = [resizedImage roundedCornerImage:imageSize.width/2.0 borderSize:0];
  return roundedImage;
}

+ (UIImage *)UIImageForThumbnailFromPhoneNumber:(NSString *)phoneNumber
{
  return [[[DFContactDataManager sharedManager] personFromPhoneNumber:phoneNumber] thumbnail];
}

@end
