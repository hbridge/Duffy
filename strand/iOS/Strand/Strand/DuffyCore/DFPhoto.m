//
//  DFPhoto.m
//  Duffy
//
//  Created by Henry Bridge on 1/30/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFPhoto.h"

#import "DFPhotoAsset.h"
#import <ImageIO/ImageIO.h>
#import "DFPhotoStore.h"
#import "DFDataHasher.h"
#import "DFAnalytics.h"
#import "NSDateFormatter+DFPhotoDateFormatters.h"
#import "ALAsset+DFExtensions.h"
#import "DFStrandPhotoAsset.h"

@implementation DFPhoto

@dynamic asset;
@dynamic creationDate;
@dynamic photoID;
@dynamic uploadThumbDate;
@dynamic uploadLargeDate;
@dynamic isUploadProcessed;
@dynamic shouldUploadImage;
@dynamic userID;
@dynamic sourceString;

// Create a new DFPhoto in a context
+ (DFPhoto *)createWithAsset:(DFPhotoAsset *)asset
                      userID:(DFUserIDType)userID
                    timeZone:(NSTimeZone *)timeZone
                   inContext:(NSManagedObjectContext *)context
{
  DFPhoto *newPhoto = [NSEntityDescription
                       insertNewObjectForEntityForName:@"DFPhoto"
                       inManagedObjectContext:context];
  newPhoto.asset = asset;
  newPhoto.creationDate = [asset creationDateForTimezone:timeZone];
  newPhoto.userID = userID;
  
  return newPhoto;
}

#pragma mark - Location

- (void)fetchReverseGeocodeDictionary:(DFPhotoReverseGeocodeCompletionBlock)completionBlock
{
  if (self.asset.location == nil) {
    completionBlock(@{});
  }
  
  CLGeocoder *geocoder = [[CLGeocoder alloc]init];
  [geocoder reverseGeocodeLocation:self.asset.location completionHandler:^(NSArray *placemarks, NSError *error) {
    NSDictionary *locationDict = @{};
    
    if (placemarks.count > 0) {
      CLPlacemark *placemark = placemarks.firstObject;
      locationDict = @{@"address": [NSDictionary dictionaryWithDictionary:placemark.addressDictionary],
                       @"pois" : [NSArray arrayWithArray:placemark.areasOfInterest]};
    }
    
    if (error) {
      BOOL possibleThrottle = NO;
      if (error.code == kCLErrorNetwork) possibleThrottle = YES;
      DDLogError(@"fetchReverseGeocodeDict error:%@, Possible rate limit:%@",
                 [error localizedDescription],
                 possibleThrottle ? @"YES" : @"NO");
    }
    
    completionBlock(locationDict);
  }];
}

- (BOOL)isDeleteableByUser:(DFUserIDType)userID
{
  if (self.userID == userID) {
    return YES;
  }
  
  return NO;
}


@end
