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
#import <RHAddressBook/AddressBook.h>
#import "UIImage+Resize.h"
#import "UIImage+RoundedCorner.h"

@implementation DFPeanutUserObject

static RHAddressBook *defaultAddressBook;
+ (RHAddressBook *)sharedAddressBook {
  if (!defaultAddressBook) {
    defaultAddressBook = [[RHAddressBook alloc] init];
  }
  return defaultAddressBook;
}

static NSMutableDictionary *defaultPhoneNumberToPersonCache;
+ (NSMutableDictionary *)phoneNumberToPersonCache {
  if (!defaultPhoneNumberToPersonCache) {
    defaultPhoneNumberToPersonCache = [[NSMutableDictionary alloc] init];
  }
  return defaultPhoneNumberToPersonCache;
}

static NSArray *defaultPeopleList;
+ (NSArray *)sharedPeopleList {
  if (!defaultPeopleList) {
    defaultPeopleList = [[DFPeanutUserObject sharedAddressBook] people];
  }
  return defaultPeopleList;
}

+ (void)clearCaches
{
  [[DFPeanutUserObject phoneNumberToPersonCache] removeAllObjects];
  defaultPeopleList = nil;
}

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

/*
 * Code to get local names from phone numbers.
 * This code is pretty general and could be pulled out to somewhere else, just here for simplicity
 */
+ (NSString *)localNameFromPhoneNumber:(NSString *)phoneNumber
{
  return [[self personFromPhoneNumber:phoneNumber] name];
}

+ (RHPerson *)personFromPhoneNumber:(NSString *)phoneNumber
{
  if (ABAddressBookGetAuthorizationStatus() != kABAuthorizationStatusAuthorized) return nil;
  if ([[DFPeanutUserObject phoneNumberToPersonCache] objectForKey:phoneNumber]) {
    return [[DFPeanutUserObject phoneNumberToPersonCache] objectForKey:phoneNumber];
  }
  
  NSArray *people = [DFPeanutUserObject sharedPeopleList];
  
  for (RHPerson *person in people) {
    RHMultiStringValue *phoneMultiValue = [person phoneNumbers];
    for (int x = 0; x < phoneMultiValue.count; x++) {
      NSString *rawPhoneNumber = [[phoneMultiValue valueAtIndex:x] description];
      
      // Get phone number into the format of +15551234567
      NSString *phoneNum = [[rawPhoneNumber componentsSeparatedByCharactersInSet:[[NSCharacterSet decimalDigitCharacterSet] invertedSet]] componentsJoinedByString:@""];
      if (![phoneNum hasPrefix:@"1"]) {
        phoneNum = [NSString stringWithFormat:@"1%@", phoneNum];
      }
      phoneNum = [NSString stringWithFormat:@"+%@", phoneNum];
      
      if ([phoneNum isEqualToString:phoneNumber]) {
        [[DFPeanutUserObject phoneNumberToPersonCache] setObject:person forKey:phoneNumber];
        return person;
      }
    }
  }
  return nil;
}

- (NSString *)firstName
{
  return [[[self fullName] componentsSeparatedByString:@" "] firstObject];
}

- (NSString *)fullName
{
  NSString *localName = [DFPeanutUserObject localNameFromPhoneNumber:self.phone_number];
  
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
  return [[self personFromPhoneNumber:phoneNumber] thumbnail];
}

@end
