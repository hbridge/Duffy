//
//  DFPeanutUserObject.m
//  Strand
//
//  Created by Henry Bridge on 7/7/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPeanutUserObject.h"
#import <CoreLocation/CoreLocation.h>
#import "UIImage+Resize.h"
#import <RestKit/RestKit.h>
#import "UIImage+RoundedCorner.h"
#import "DFContactDataManager.h"
#import "EKMappingBlocks+DFMappingBlocks.h"
#import "DFPeanutContact.h"

DFPeanutUserRelationshipType DFPeanutUserRelationshipFriend = @"friend";
DFPeanutUserRelationshipType DFPeanutUserRelationshipForwardFriend = @"forward_friend";
DFPeanutUserRelationshipType DFPeanutUserRelationshipReverseFriend = @"reverse_friend";
DFPeanutUserRelationshipType DFPeanutUserRelationshipConnection = @"connection";

@implementation DFPeanutUserObject

+ (RKObjectMapping *)rkObjectMapping
{
  RKObjectMapping *objectMapping = [RKObjectMapping mappingForClass:[self class]];
  [objectMapping addAttributeMappingsFromArray:[self simpleAttributeKeys]];
  [objectMapping addAttributeMappingsFromArray:[self dateAttributeKeys]];
  
  return objectMapping;
}

+ (EKObjectMapping *)objectMapping {
  return [EKObjectMapping mappingForClass:self withBlock:^(EKObjectMapping *mapping) {
    [mapping mapPropertiesFromArray:[self simpleAttributeKeys]];
    for (NSString *key in [self dateAttributeKeys]) {
      [mapping mapKeyPath:key toProperty:key
           withValueBlock:[EKMappingBlocks dateMappingBlock]
             reverseBlock:[EKMappingBlocks dateReverseMappingBlock]];
    }
  }];
}


+ (NSArray *)dateAttributeKeys
{
  return @[@"last_checkin_timestamp",
           @"first_run_sync_timestamp",
           @"last_photo_timestamp",
           @"last_photo_update_timestamp",
           @"last_actions_list_request_timestamp"];
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
           @"first_run_sync_count",
           @"invites_remaining",
           @"invites_sent",
           @"shared_strand",
           @"has_sms_authed",
           @"added",
           @"invited",
           @"relationship",
           @"friend_connection_id",
           @"forward_friend_only",
           ];
}

- (instancetype)initWithPeanutContact:(DFPeanutContact *)peanutContact
{
  self = [self init];
  if (self) {
    self.display_name = peanutContact.name;
    self.phone_number = peanutContact.phone_number;
    self.id = peanutContact.user.longLongValue;
  }
  return self;
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
  if (self.id == otherUser.id &&
      [self.relationship isEqualToString:otherUser.relationship])
    return YES;
  
  return NO;
}


- (NSString *)firstName
{
  return [[[self fullName] componentsSeparatedByString:@" "] firstObject];
}

- (NSString *)fullName
{
  NSString *localName = [[DFContactDataManager sharedManager] localNameFromPhoneNumber:self.phone_number];
  
  if ([localName isNotEmpty]) {
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
  UIImage *thumbnail = [self thumbnail];
  if (!thumbnail || size.width == 0 || size.height == 0) return nil;
  CGSize imageSize = CGSizeMake(size.width * [[UIScreen mainScreen] scale],
                                size.height * [[UIScreen mainScreen] scale]);
  UIImage *resizedImage = [thumbnail resizedImage:imageSize
                         interpolationQuality:kCGInterpolationDefault];
  UIImage *roundedImage = [resizedImage roundedCornerImage:imageSize.width/2.0 borderSize:0];
  return roundedImage;
}

+ (UIImage *)UIImageForThumbnailFromPhoneNumber:(NSString *)phoneNumber
{
  return [[[DFContactDataManager sharedManager] personFromPhoneNumber:phoneNumber] thumbnail];
}

+ (DFPeanutUserObject *)TeamSwapUser
{
  DFPeanutUserObject *teamSwapUser = [[DFPeanutUserObject alloc] init];
  teamSwapUser.id = NSUIntegerMax;
  teamSwapUser.display_name = @"TS";
  teamSwapUser.phone_number = @"TS";
  return teamSwapUser;
}

- (BOOL)hasAuthedPhone
{
  return [self.has_sms_authed boolValue];
}

@end
